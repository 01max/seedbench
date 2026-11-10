require 'digest'

module Ai
  class EvidenceCatalog
    MAX_TEXT_BYTES = 1800

    def self.call(release:)
      new(release).call
    end

    def initialize(release)
      @release = release
      @payload = release.payload_revisions.order(number: :desc).first
    end

    def call
      reports = @release.evidence_items.where(payload_revision: @payload, kind: 'inspection').order(id: :desc).limit(3).to_a
      latest = reports.first
      raise Failure.new(:inspection_required) unless @payload && @release.inspection_state == 'succeeded' && latest && latest.data['error'].nil?

      reviewed + reports.flat_map { |report| inspection(report, report == latest) } + records
    end

    private

    def reviewed
      relation = @release.reviewed_facts.where(payload_revision: @payload)
      facts = relation.where(id: relation.select('MAX(id)').group(:field)).order(:field).to_a
      return [] if facts.empty?

      [ item("facts-#{facts.map(&:id).join('-')}", 'reviewed', I18n.t('ai.sources.reviewed'),
        facts.to_h { |fact| [ fact.field, fact.value ] }.to_json, { 'fact_ids' => facts.map(&:id) }, true) ]
    end

    def inspection(report, routine)
      metadata = Array(report.data['metadata']).first(12).map { |entry| entry.slice('field', 'value', 'source') }
      items = [ fragment(report, 'metadata', 0, metadata.to_json, report.source, routine) ]
      items << fragment(report, 'structure', 0, report.data.fetch('structure', {}).to_json, report.source, routine)
      items + excerpts(report, 'samples', 'excerpt', routine) + excerpts(report, 'contents', 'contents', routine)
    end

    def excerpts(report, key, kind, routine)
      Array(report.data[key]).first(12).each_with_index.map do |sample, index|
        fragment(report, kind, index, sample.fetch('text'), sample.fetch('source'), routine)
      end
    end

    def records
      @release.evidence_items.where(payload_revision: @payload, kind: 'edition_record').order(id: :desc).limit(3).filter_map do |record|
        next if record.data['lookup_error']

        data = record.data.slice('queried_isbn', 'record_format', 'edition_medium', 'isbn_matches_query', 'publishers', 'publish_date', 'metadata')
        fragment(record, 'edition', 0, data.to_json, record.source, true)
      end
    end

    def fragment(report, kind, index, text, source, routine)
      item("#{report.evidence_key}:#{kind}:#{index}", kind, source, text,
        { 'evidence_item_id' => report.id, 'evidence_key' => report.evidence_key }, routine)
    end

    def item(identity, kind, source, text, provenance, routine)
      digest = Digest::SHA256.hexdigest("#{identity}\n#{text}")
      { 'id' => "ev-#{digest.first(32)}", 'kind' => kind, 'source' => source.to_s.truncate_bytes(200, omission: ''),
        'text' => text.to_s.truncate_bytes(MAX_TEXT_BYTES, omission: ''), 'truncated' => text.to_s.bytesize > MAX_TEXT_BYTES,
        'provenance' => provenance, 'routine' => routine }
    end
  end
end
