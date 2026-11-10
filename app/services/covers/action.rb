module Covers
  class Action
    def self.call(release_id:, expected_revision:, attributes:)
      if attributes['kind'] == 'lookup'
        return Ebooks::Action.call(release_id: release_id, kind: 'lookup', expected_revision: expected_revision, isbn: attributes['isbn'])
      end
      raise Failure.new(:invalid_source) unless attributes['kind'] == 'select'

      kind, evidence, candidate = attributes.fetch('source', '').split(':', 3)
      source = attributes.slice('image', 'image_url').merge('evidence_id' => evidence, 'candidate_id' => candidate)
      Select.call(release_id: release_id, expected_revision: expected_revision, kind: kind, attributes: source, review: attributes.fetch('review', {}))
    end
  end
end
