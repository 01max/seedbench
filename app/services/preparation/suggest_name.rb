module Preparation
  class SuggestName
    def self.call(release:)
      values = Releases::EditorValues.call(release: release)
      payload = release.payload_revisions.order(number: :desc).first
      raise Failure.new(:inspection_required) unless payload

      names = Providers::C411::EbookNaming.call(title: values.fetch('title'), author: values.fetch('author'), language: values.fetch('language'), format: payload.format)
      Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { proposed_name: names.release })
    end
  end
end
