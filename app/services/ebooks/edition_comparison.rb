module Ebooks
  class EditionComparison
    class << self
      def call(release:, payload:)
        groups(release, payload).filter_map do |field, candidates|
          conflict(release, payload, field, candidates) if %w[title author isbn edition language].include?(field)
        end
      end

      private

      def groups(release, payload)
        release.evidence_items.where(payload_revision_id: payload.id).flat_map do |item|
          Array(item.data["candidates"]).map { |candidate| candidate.merge("evidence_key" => item.evidence_key) }
        end.group_by { |candidate| candidate["field"] }
      end

      def conflict(release, payload, field, candidates)
        reviewed = release.reviewed_facts.where(field: field, payload_revision_id: payload.id).order(:number).last
        values = candidates.map { |candidate| comparable(field, candidate["value"]) }
        values << comparable(field, reviewed.value) if reviewed
        return unless values.compact.uniq.size > 1

        { "field" => field, "candidates" => candidates, "reviewed_value" => reviewed&.value }
      end

      def comparable(field, value)
        field == "isbn" ? Isbn.canonical(value) : value.to_s.unicode_normalize.downcase.strip
      end
    end
  end
end
