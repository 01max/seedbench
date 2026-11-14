module Releases
  class MarkCheck
    class NotManual < StandardError; end
    KEYS = %w[edition_review text_review].freeze

    class << self
      def call(release_id:, key:, checked:, expected_revision:)
        raise NotManual, I18n.t('workbench.errors.automatic_check') unless KEYS.include?(key)
        raise ArgumentError, I18n.t('workbench.errors.invalid_mark') unless [ true, false ].include?(checked)

        release = Release.find(release_id)
        release.with_lock do
          raise RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

          append(release, key, checked)
        end
      end

      private

      def append(release, key, checked)
        previous = release.manual_checks.where(key: key).order(number: :desc).first
        return previous if !!previous&.checked_at_revision?(release.input_revision) == checked

        mark = release.manual_checks.create!(key: key, number: (previous&.number || 0) + 1,
          checked: checked, input_revision: release.input_revision, actor: 'operator')
        RecordEvent.call(release_id: release.id, name: 'checklist.changed', actor: 'operator', data: { key: key, checked: checked })
        mark
      end
    end
  end
end
