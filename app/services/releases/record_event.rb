module Releases
  class RecordEvent
    def self.call(release_id:, name:, actor: "system", data: {})
      EventMetadata.validate!(data)
      raise EventMetadata::Unsafe, "Invalid event name or actor." unless
        name.is_a?(String) && name.match?(/\A[a-z][a-z0-9_.]{0,79}\z/) && %w[system operator].include?(actor)

      release = Release.find(release_id)
      release.with_lock do
        sequence = release.release_events.maximum(:sequence).to_i + 1
        release.release_events.create!(name: name, actor: actor, data: data, sequence: sequence,
          input_revision: release.input_revision, occurred_at: Time.current)
      end
    end
  end
end
