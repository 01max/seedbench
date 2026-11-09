module Releases
  class AcknowledgeFinding
    class NotUncertain < StandardError; end
    class StaleFinding < StandardError; end

    class << self
      def call(release_id:, finding_id:, number:, acknowledged:, expected_revision:)
        release = Release.find(release_id)
        release.with_lock do
          raise RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

          finding = release.findings.find(finding_id)
          validate_current!(release, finding, number)
          append(release, finding, acknowledged)
        end
      end

      private

      def validate_current!(release, finding, number)
        raise StaleFinding, I18n.t("workbench.errors.stale_finding") unless current?(release, finding, number)
        raise NotUncertain, I18n.t("workbench.errors.mechanical_failure") unless finding.severity == "uncertainty"
      end

      def current?(release, finding, number)
        latest = release.findings.where(code: finding.code).maximum(:number)
        payload_id = release.payload_revisions.order(number: :desc).pick(:id)
        !finding.data["resolved"] && latest == finding.number && number == finding.number && payload_id == finding.payload_revision_id
      end

      def append(release, finding, acknowledged)
        raise ArgumentError, I18n.t("workbench.errors.invalid_acknowledgement") unless [ true, false ].include?(acknowledged)

        previous = finding.finding_acknowledgements.order(:id).last
        return previous if (previous&.acknowledged || false) == acknowledged

        acknowledgement = finding.finding_acknowledgements.create!(release: release, acknowledged: acknowledged, actor: "operator")
        RecordEvent.call(release_id: release.id, name: "finding.acknowledgement_changed", actor: "operator",
          data: { finding_id: finding.id, number: finding.number, acknowledged: acknowledged })
        acknowledgement
      end
    end
  end
end
