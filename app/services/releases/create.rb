module Releases
  class Create
    ROLES = %w[publishing torrent_client ai image_host].freeze

    def self.call(title: nil, author: nil, automatic_ai: true)
      Release.transaction do
        release = Release.create!(title: title, author: author, automatic_ai: automatic_ai)
        ROLES.each { |role| release.provider_assignments.create!(role: role) }
        RecordEvent.call(release_id: release.id, name: "release.created", actor: "operator")
        release
      end
    end
  end
end
