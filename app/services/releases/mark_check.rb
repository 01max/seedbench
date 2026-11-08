module Releases
  class MarkCheck
    class NotManual < StandardError; end
    LABELS = { "edition_review" => "Édition relue", "text_review" => "Texte relu" }.freeze

    def self.call(release_id:, key:, checked:, expected_revision:)
      raise NotManual, "Ce contrôle est automatique et ne peut pas être coché manuellement." unless LABELS.key?(key)
      raise ArgumentError, "A checklist mark must be true or false." unless [ true, false ].include?(checked)

      release = Release.find(release_id)
      release.with_lock do
        raise RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        append(release, key, checked)
      end
    end

    def self.append(release, key, checked)
      previous = release.manual_checks.where(key: key).order(number: :desc).first
      return previous if (previous&.checked || false) == checked

      mark = release.manual_checks.create!(key: key, number: (previous&.number || 0) + 1,
        checked: checked, input_revision: release.input_revision, actor: "operator")
      RecordEvent.call(release_id: release.id, name: "checklist.changed", actor: "operator", data: { key: key, checked: checked })
      mark
    end
    private_class_method :append
  end
end
