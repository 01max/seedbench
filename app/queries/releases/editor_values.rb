module Releases
  class EditorValues
    METADATA = %w[title author].freeze
    FACTS = %w[isbn edition language].freeze
    CONTENT = %w[presentation notes bbcode nfo].freeze

    def self.call(release:)
      metadata = METADATA.index_with { |field| release.public_send(field).to_s }
      facts = latest(release.reviewed_facts, :field).pluck(:field, :value).to_h
      content = latest(release.content_revisions, :kind).pluck(:kind, :body).to_h
      metadata.merge(FACTS.index_with { |field| facts[field].to_s })
        .merge(CONTENT.index_with { |kind| content[kind].to_s })
    end

    def self.latest(relation, group)
      relation.where(id: relation.select("MAX(id)").group(group))
    end
    private_class_method :latest
  end
end
