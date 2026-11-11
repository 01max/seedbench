module Drafts
  class Refresh
    class << self
      def call(connection: nil)
        return refresh(connection) if connection
        ProviderConnection.where(provider: 'c411').reject(&:configuration_incomplete?).flat_map do |candidate|
          refresh(candidate)
        end
      end

      private

      def refresh(connection)
        errors = []
        Import.call(connection: connection) { |id, error| errors << draft_failure(connection, id, error) }
        errors.concat(connection.draft_links.includes(:release).find_each.filter_map { |link| refresh_link(link) })
      rescue Providers::Failure, Failure => error
        [ I18n.t('drafts.sync_failed', connection: connection.label, message: error.message) ]
      end

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
