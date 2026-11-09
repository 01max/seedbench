module Releases
  class EditorValues
    METADATA = %w[title author].freeze
    FACTS = %w[isbn edition language publisher publication_year isbn_kind].freeze
    CONTENT = %w[presentation notes bbcode nfo].freeze

    class << self
      def call(release:)
        metadata = METADATA.index_with { |field| release.public_send(field).to_s }
        facts = latest(release.reviewed_facts, :field).pluck(:field, :value).to_h
        content = latest(release.content_revisions, :kind).pluck(:kind, :body).to_h
        metadata.merge(fact_values(facts))
          .merge(CONTENT.index_with { |kind| content[kind].to_s })
      end

      private

      def fact_values(facts)
        FACTS.index_with { |field| field == 'isbn_kind' ? facts[field].presence || 'unknown' : facts[field].to_s }
      end

      def latest(relation, group)
        relation.where(id: relation.select('MAX(id)').group(group))
      end
    end
  end
end
