module Releases
  class Revise
    class InvalidChanges < StandardError; end
    EDITABLE = %w[title author].freeze

    def self.call(release_id:, expected_revision:, changes:)
      changes = validate_changes!(changes)
      release = Release.find(release_id)
      release.with_lock do
        raise RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision
        return release if changes.all? { |field, value| release.public_send(field) == value }

        release.update!(changes.merge("input_revision" => release.input_revision + 1))
        RecordEvent.call(release_id: release.id, name: "release.revised", actor: "operator", data: { fields: changes.keys.sort })
        release
      end
    end

    def self.validate_changes!(changes)
      raise InvalidChanges, "Only title and author text can be revised here." unless
        editable_fields?(changes) && text_values?(changes)

      changes.stringify_keys
    end
    private_class_method :validate_changes!

    def self.editable_fields?(changes)
      changes.is_a?(Hash) && changes.any? && (changes.keys.map(&:to_s) - EDITABLE).empty?
    end
    private_class_method :editable_fields?

    def self.text_values?(changes)
      changes.values.all? { |value| value.nil? || value.is_a?(String) }
    end
    private_class_method :text_values?
  end
end
