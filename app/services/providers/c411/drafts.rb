module Providers
  class C411
    class Drafts
      Listing = Data.define(:ids, :count, :maximum)
      PATH = '/api/user/drafts'.freeze

      def initialize(connection)
        @connection = connection
      end

      def list
        data = request(:get, PATH)
        invalid! unless data['data'].is_a?(Array) && data['data'].size <= 100
        ids = data['data'].map do |item|
          invalid! unless item.is_a?(Hash)
          identity(item.fetch('id'))
        end
        Listing.new(ids: ids.uniq, count: data['count'], maximum: data['maxAllowed'])
      rescue KeyError, TypeError
        invalid!
      end

      def read(id)
        data = request(:get, "#{PATH}/#{identity(id)}").fetch('data')
        invalid! unless data.is_a?(Hash) && identity(data['id']) == identity(id)
        data
      rescue KeyError
        invalid!
      end

      def create(content)
        data = request(:post, PATH, content).fetch('data')
        invalid! unless data.is_a?(Hash)
        identity(data['id'])
      rescue KeyError
        invalid!
      end

      def update(id, content)
        request(:patch, "#{PATH}/#{identity(id)}", content)
      end

      def delete(id)
        request(:delete, "#{PATH}/#{identity(id)}")
      end

      private

      def identity(value)
        string = value.to_s
        invalid! unless string.match?(/\A[a-zA-Z0-9_-]{1,100}\z/)
        string
      end

      def request(method, path, body = nil)
        headers = { 'Authorization' => "Bearer #{@connection.credentials.fetch('api_key')}", 'Content-Type' => 'application/json' }
        response = Http.call(endpoint: @connection.endpoint, path: path, method: method, body: body, headers: headers)
        data = Http.json(response)
        invalid! unless data.is_a?(Hash) && data['success'] == true
        data
      end

      def invalid!
        raise Failure.new('invalid_response', I18n.t('drafts.errors.invalid_response'))
      end
    end
  end
end
