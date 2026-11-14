module Publications
  # Refreshes the linked draft after C411 accepts a publication and reports any observation failure
  # separately.
  class DraftObservation
    def self.call(release:)
      return 'unlinked' unless release.reload.draft_link

      Drafts::AfterPublication.call(release_id: release.id) ? 'present' : 'missing'
    rescue Providers::Failure, Drafts::Failure
      'unavailable'
    end
  end
end
