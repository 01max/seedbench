module Drafts
  class Refresh
    class << self
      def call(connection: nil)
        return refresh(connection) if connection
        ProviderConnection.where(provider: 'c411').filter_map do |candidate|
          next if candidate.configuration_incomplete?
          refresh(candidate)
        end
      end

      private

      def refresh(connection)
        Import.call(connection: connection)
        connection.draft_links.includes(:release).find_each { |link| Sync.call(link: link) }
        nil
      rescue Providers::Failure, Failure => error
        I18n.t('drafts.sync_failed', connection: connection.label, message: error.message)
      end
    end
  end
end
