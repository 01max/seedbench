require_relative "runtime_access"

module RuntimeWorkbench
  def self.prepare(release)
    Releases::Save.call(release_id: release.id, expected_revision: 0,
      changes: { bbcode: "Preserved human content", nfo: "Preserved full NFO\nSecond line", presentation: "Preserved presentation" })
    Releases::MarkCheck.call(release_id: release.id, key: "text_review", checked: true, expected_revision: 1)
    finding = release.findings.create!(payload_revision: release.payload_revisions.sole, code: "synthetic_uncertainty", number: 1,
      severity: "uncertainty", message: "Synthetic uncertainty", input_revision: 1)
    Releases::AcknowledgeFinding.call(release_id: release.id, finding_id: finding.id, number: 1, acknowledged: true, expected_revision: 1)
  end

  def self.verify(release)
    values = Releases::EditorValues.call(release: release)
    expected = { "bbcode" => "Preserved human content", "nfo" => "Preserved full NFO\nSecond line", "presentation" => "Preserved presentation" }
    abort "Full editor text changed across recreation" unless values.slice(*expected.keys) == expected
    abort "Manual review changed across recreation" unless release.manual_checks.sole.checked
    abort "Uncertainty acknowledgement lost" unless release.finding_acknowledgements.sole.acknowledged
    verify_browser(release, expected)
    puts "Full editor text, reversible review history and uncertainty acknowledgements survived container recreation."
  end

  def self.verify_browser(release, expected)
    cookies = JSON.parse(Rails.application.config.x.storage.fetch(:scratch).join("runtime-browser-cookies.json").read)
    response = RuntimeAccess.request(Net::HTTP::Get, "/releases/#{release.id}", cookies)
    abort "Persisted workbench did not reopen" unless response.code == "200"
    document = Nokogiri::HTML5(response.body)
    expected.each do |kind, body|
      abort "Reopened editor lost #{kind}" unless document.at_css("#edit_#{kind}").text == body
    end
    abort "Reopened manual mark was unchecked" unless document.at_css("#mark-text_review[checked]")
  end
end
