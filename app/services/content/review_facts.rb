module Content
  class ReviewFacts
    def self.call(release_id:, expected_revision:)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        inputs = Inputs.new(release)
        values = Releases::EditorValues.call(release: release).slice(*Inputs::BOOK_FIELDS)
        changed = values.reject { |field, value| value.blank? || inputs.fact(field) == value }
        append(release, inputs.payload, changed) if changed.any?
        release
      end
    end

    class << self
      private

      def append(release, payload, values)
        raise Releases::Save::InvalidChanges.new(base: I18n.t('workbench.errors.payload_required')) unless payload

        values.each do |field, value|
          release.reviewed_facts.create!(payload_revision: payload, field: field, value: value,
            number: release.reviewed_facts.where(field: field).maximum(:number).to_i + 1, actor: 'operator', reviewed_at: Time.current)
        end
        release.update!(input_revision: release.input_revision + 1)
        Ebooks::Findings.call(release: release, payload: payload)
        Releases::RecordEvent.call(release_id: release.id, name: 'content.facts_reviewed', actor: 'operator', data: { fields: values.keys })
      end
    end
  end
end
