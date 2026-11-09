module Ebooks
  class Readiness
    def self.call(release:)
      snapshot = Releases::Snapshot.call(release: release)
      reasons = snapshot.findings.filter_map do |finding|
        acknowledged = finding.finding_acknowledgements.max_by(&:id)&.acknowledged
        finding.message if finding.severity == "failure" || !acknowledged
      end
      reasons << I18n.t("ebooks.inspection_required") unless release.inspection_state == "succeeded"
      reasons.uniq
    end
  end
end
