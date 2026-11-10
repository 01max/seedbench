module Ai
  class EvidencePack
    VERSION = 'focused-evidence-v1'.freeze
    MAX_BYTES = 32_768

    def self.call(release:, scope: {})
      catalog = EvidenceCatalog.call(release: release)
      scope = scope.stringify_keys
      raise Failure.new(:scope_required) unless [ nil, 'routine', 'selected' ].include?(scope['mode'])

      items = scope['mode'] == 'selected' ? selected(catalog, scope) : routine(catalog)
      build(release, scope, catalog, items)
    end

    class << self
      private

      def build(release, scope, catalog, items)
        pack = { 'version' => VERSION, 'payload_revision_id' => release.payload_revisions.order(number: :desc).pick(:id),
          'scope' => scope.slice('mode', 'note').reverse_merge('mode' => 'routine'), 'items' => items.map { |item| item.except('routine') },
          'omitted_count' => catalog.size - items.size, 'whole_book' => false }
        raise Failure.new(:pack_too_large) if JSON.generate(pack).bytesize > MAX_BYTES

        pack
      end

      def selected(catalog, scope)
        ids = scope['evidence_ids']
        raise Failure.new(:scope_required) unless valid_selection?(ids, scope['note'])

        selected = ids.map { |id| catalog.find { |item| item['id'] == id } }
        raise Failure.new(:scope_required) if selected.any?(&:nil?)

        selected
      end

      def valid_selection?(ids, note)
        return false unless ids.is_a?(Array) && ids.uniq.size == ids.size && ids.size.between?(1, 8)

        note.is_a?(String) && note.strip.length.between?(20, 500)
      end

      def routine(catalog)
        available = catalog.select { |item| item.fetch('routine') }
        excerpts = available.select { |item| item['kind'] == 'excerpt' }
        kinds = %w[reviewed metadata structure contents edition]
        selected = kinds.flat_map { |kind| available.select { |item| item['kind'] == kind }.first(kind == 'edition' ? 2 : 1) }
        (selected + excerpts.first(2) + excerpts.last(1)).uniq { |item| item['id'] }.first(12)
      end
    end
  end
end
