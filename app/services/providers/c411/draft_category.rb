module Providers
  class C411
    class DraftCategory
      def self.call(connection:, format:)
        new(connection).call(format)
      end

      def initialize(connection)
        @connection = connection
      end

      def call(format)
        category, subcategory = category_ids
        types = read("/api/categories/#{subcategory}/options")
        options = resolve_options(types, format)
        { 'categoryId' => category, 'subcategoryId' => subcategory, 'options' => options }
      rescue KeyError, TypeError
        raise ::Drafts::Failure.new(:category_changed), cause: nil
      end

      private

      def category_ids
        category = read('/api/categories').find { |item| item['slug'] == 'ebook' }
        subcategory = category&.fetch('subcategories', [])&.find { |item| item['slug'] == 'livres' }
        raise ::Drafts::Failure.new(:category_changed) unless category && subcategory
        [ category.fetch('id'), subcategory.fetch('id') ]
      end

      def resolve_options(types, format)
        options = [ option(types, 'format-ebook', format), option(types, 'langue-bd', 'francais') ].to_h
        required = types.select { |type| type['isRequired'] }
        raise ::Drafts::Failure.new(:category_changed) unless required.all? { |type| options.key?(type['id'].to_s) }
        options
      end

      def option(types, slug, value)
        type = types.find { |item| item['slug'] == slug }
        selected = type&.fetch('values', [])&.find { |item| item['slug'] == value }
        raise ::Drafts::Failure.new(:category_changed) unless type && selected
        [ type.fetch('id').to_s, selected.fetch('id') ]
      end

      def read(path)
        response = Http.call(endpoint: @connection.endpoint, path: path, headers: { 'Authorization' => "Bearer #{@connection.credentials.fetch('api_key')}" })
        data = Http.json(response)
        raise ::Drafts::Failure.new(:category_changed) unless data.is_a?(Hash) && data['data'].is_a?(Array)
        data.fetch('data')
      end
    end
  end
end
