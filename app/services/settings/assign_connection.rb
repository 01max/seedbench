module Settings
  class AssignConnection
    class AlreadyAssigned < StandardError; end

    class << self
      def call(release_id:, role:, connection_id:, expected_revision:)
        release = Release.find(release_id)
        connection = ProviderConnection.find_by(id: connection_id, role: role)
        raise SetDefaults::Invalid, I18n.t('messages.settings.assign_connection.connexion_introuvable_pour_ce_role') unless connection

        release.with_lock do
          raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

          assign(release, role, connection)
        end
        release
      end

      private

      def assign(release, role, connection)
        assignment = release.provider_assignments.find_by!(role: role)
        return if assignment.provider_connection_id == connection.id
        raise AlreadyAssigned, I18n.t('messages.settings.assign_connection.ce_role_possede_deja_une_identite') if assignment.provider_connection_id

        assignment.update!(provider_connection: connection, assigned_at: Time.current)
        release.update!(input_revision: release.input_revision + 1)
        Releases::RecordEvent.call(release_id: release.id, name: 'provider.assigned', actor: 'operator', data: { role: role, connection_id: connection.id })
      end
    end
  end
end
