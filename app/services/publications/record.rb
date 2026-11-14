module Publications
  # Appends the publication workflow's observed result to the release history.
  class Record
    def self.call(operation:, result:)
      Releases::RecordEvent.call(release_id: operation.release_id, name: 'publication.observed', data: result.merge('operation_id' => operation.id))
      result
    end
  end
end
