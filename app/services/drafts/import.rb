module Drafts
  # Keeps a read-only queue entry for each C411 draft that has no local link.
  class Import
    class << self
      def call(connection:)
        version = connection.credentials_version
        listing = Providers::C411::Drafts.new(connection).list
        connection.with_lock do
          raise Failure.new(:connection_changed) unless connection.credentials_version == version

          existing = connection.draft_links.where(remote_id: listing.ids).pluck(:remote_id)
          listing.entries.except(*existing).each { |id, summary| import(connection, id, summary) }
        end
        listing
      end

      private

      def import(connection, id, summary)
        title = summary.values_at('title', 'name').find { |value| value.is_a?(String) && value.valid_encoding? && value.present? }
        title = title&.strip&.first(Releases::Save::LIMITS.fetch('title'))
        release = Release.create!(title: title, search_text: Releases::SearchText.call(title: title), automatic_ai: false, draft_state: 'synced')
        connection.draft_links.create!(release: release, remote_id: id)
        Releases::RecordEvent.call(release_id: release.id, name: Release::C411_IMPORT_EVENT, data: { remote_id: id })
      end
    end
  end
end
