module Ebooks
  class Findings
    CODES = %w[inspection_failure sampled_pages edition_conflict edition_medium invalid_reviewed_isbn].freeze

    def self.call(release:, payload:)
      new(release, payload).call
    end

    def initialize(release, payload)
      @release, @payload = release, payload
      @evidence = release.evidence_items.where(payload_revision_id: payload.id)
    end

    def call
      report = @evidence.where(kind: "inspection").order(:id).last
      return unless report

      values = observations(report)
      CODES.each { |code| revise(code, values[code]) }
    end

    private

    def observations(report)
      data = report.data
      values = {}
      values["inspection_failure"] = [ "failure", data.slice("error") ] if data["error"]
      pages = data.dig("structure", "pages_without_text_in_sample")
      values["sampled_pages"] = [ "uncertainty", { "pages_without_text" => pages } ] if pages.present?
      conflicts = EditionComparison.call(release: @release, payload: @payload)
      values["edition_conflict"] = [ "uncertainty", { "conflicts" => conflicts } ] if conflicts.any?
      values.merge!(edition_observations)
      values
    end

    def edition_observations
      values = {}
      isbn = @release.reviewed_facts.where(field: "isbn", payload_revision_id: @payload.id).order(:number).last&.value
      values["invalid_reviewed_isbn"] = [ "failure", { "isbn" => isbn } ] if isbn.present? && !Isbn.valid?(isbn)
      records = edition_records
      values["edition_medium"] = [ "uncertainty", { "records" => records } ] if records.any?
      values
    end

    def edition_records
      @evidence.where(kind: "edition_record").where("json_extract(data, '$.source_url') IS NOT NULL").order(:id)
        .map { |item| item.data.slice("source_url", "edition_medium", "record_format", "publishers", "publish_date") }.uniq
    end

    def revise(code, observation)
      previous = @release.findings.where(code: code).order(:number).last
      return if !observation && !previous

      severity, material = observation || [ previous.severity, { "resolved" => true } ]
      fingerprint = Digest::SHA256.hexdigest(JSON.generate(comparable(material)))
      return if previous&.payload_revision_id == @payload.id && previous.data["fingerprint"] == fingerprint

      append(code, severity, material, fingerprint, previous)
    end

    def comparable(value)
      case value
      when Hash then value.except("evidence_key").transform_values { |item| comparable(item) }
      when Array then value.map { |item| comparable(item) }.uniq
      else value
      end
    end

    def append(code, severity, material, fingerprint, previous)
      error = material["error"]
      message = error ? I18n.t("ebooks.errors.#{error}", default: I18n.t("ebooks.errors.parser_failed")) : I18n.t("ebooks.findings.#{code}")
      @release.findings.create!(payload_revision: @payload, code: code, number: previous&.number.to_i + 1,
        severity: severity, message: message, input_revision: @release.input_revision,
        data: material.merge("fingerprint" => fingerprint, "evidence_keys" => @evidence.order(:id).pluck(:evidence_key)))
    end
  end
end
