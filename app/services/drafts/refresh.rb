module Drafts
  # Imports new drafts and synchronizes known links, collecting failures while continuing with other
  # drafts.
  class Refresh
    class << self
      def call(connection:)
        Import.call(connection: connection)
        imported = ReleaseEvent.where(name: Release::C411_IMPORT_EVENT).select(:release_id)
        connection.draft_links.where.not(release_id: imported).includes(:release).find_each.filter_map { |link| refresh_link(link) }
      rescue Providers::Failure, Failure => error
        [ I18n.t('drafts.sync_failed', connection: connection.label, message: error.message) ]
      end

      private

      def refresh_link(link)
        Sync.call(link: link)
        nil
      rescue Providers::Failure, Failure => error
        draft_failure(link.provider_connection, link.remote_id, error)
      end

      def draft_failure(connection, id, error)
        I18n.t('drafts.sync_draft_failed', connection: connection.label, id: id, message: error.message)
      end
    end
  end
end
