module Settings
  class AssignConnection
    class AlreadyAssigned < StandardError; end

    def self.call(release_id:, role:, connection_id:, expected_revision:)
      release = Release.find(release_id)
      connection = ProviderConnection.find_by(id: connection_id, role: role)
      raise SetDefaults::Invalid, "Connexion introuvable pour ce rôle." unless connection

      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        assign(release, role, connection)
      end
      release
    end

    def self.assign(release, role, connection)
      assignment = release.provider_assignments.find_by!(role: role)
      return if assignment.provider_connection_id == connection.id
      raise AlreadyAssigned, "Ce rôle possède déjà une identité enregistrée; elle reste inchangée." if assignment.provider_connection_id

      assignment.update!(provider_connection: connection, assigned_at: Time.current)
      release.update!(input_revision: release.input_revision + 1)
      Releases::RecordEvent.call(release_id: release.id, name: "provider.assigned", actor: "operator", data: { role: role, connection_id: connection.id })
    end
    private_class_method :assign
  end
end
