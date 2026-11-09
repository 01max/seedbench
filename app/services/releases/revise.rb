module Releases
  class Revise
    class InvalidChanges < StandardError; end
    EDITABLE = %w[title author].freeze

    class << self
      def call(release_id:, expected_revision:, changes:)
        changes = validate_changes!(changes)
        release = Release.find(release_id)
        release.with_lock do
          raise RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision
          return release if changes.all? { |field, value| release.public_send(field) == value }

          release.update!(revision_attributes(release, changes))
          RecordEvent.call(release_id: release.id, name: 'release.revised', actor: 'operator', data: { fields: changes.keys.sort })
          release
        end
      end

      private

      def revision_attributes(release, changes)
        changes.merge('input_revision' => release.input_revision + 1,
          'search_text' => SearchText.call(title: changes.fetch('title', release.title), author: changes.fetch('author', release.author)))
      end

      def validate_changes!(changes)
        raise InvalidChanges, I18n.t('messages.releases.revise.only_title_and_author_text_can') unless
          editable_fields?(changes) && text_values?(changes)

        changes.stringify_keys
      end

      def editable_fields?(changes)
        changes.is_a?(Hash) && changes.any? && (changes.keys.map(&:to_s) - EDITABLE).empty?
      end

      def text_values?(changes)
        changes.values.all? { |value| value.nil? || value.is_a?(String) }
      end
    end
  end
end
