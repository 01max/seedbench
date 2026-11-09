module Releases
  class Create
    ROLES = %w[publishing torrent_client ai image_host].freeze

    def self.call(title: nil, author: nil)
      Release.transaction do
        defaults = Settings::DefaultsSnapshot.call
        release = Release.create!(title: title, author: author, automatic_ai: defaults.automatic_ai,
          search_text: SearchText.call(title: title, author: author))
        ROLES.each do |role|
          id = defaults.connection_ids[role]
          release.provider_assignments.create!(role: role, provider_connection_id: id, assigned_at: id ? Time.current : nil)
        end
        RecordEvent.call(release_id: release.id, name: 'release.created', actor: 'operator')
        release
      end
    end
  end
end
