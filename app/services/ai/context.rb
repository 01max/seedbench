require 'digest'

module Ai
  class Context
    def self.call(release:)
      payload = release.payload_revisions.order(number: :desc).first
      facts = release.reviewed_facts.where(payload_revision: payload)
      evidence = release.evidence_items.where(payload_revision: payload, kind: %w[inspection edition_record])
      material = { payload_id: payload&.id, facts: facts.where(id: facts.select('MAX(id)').group(:field)).order(:field).pluck(:id),
        evidence: evidence.order(:id).pluck(:id) }
      Digest::SHA256.hexdigest(JSON.generate(material))
    end
  end
end
