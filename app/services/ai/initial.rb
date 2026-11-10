module Ai
  class Initial
    class << self
      def call(release:)
        return unless enabled?(release)

        %w[assessment prose].each do |purpose|
          Request.call(release_id: release.id, expected_revision: release.input_revision, purpose: purpose, initial: true)
        rescue Failure => error
          Releases::RecordEvent.call(release_id: release.id, name: 'ai.skipped', data: { purpose: purpose, error_code: error.code })
        end
      end

      private

      def enabled?(release)
        connection = release.provider_assignments.find_by(role: 'ai')&.provider_connection
        release.automatic_ai && connection&.provider == 'openai' && !connection.configuration_incomplete?
      end
    end
  end
end
