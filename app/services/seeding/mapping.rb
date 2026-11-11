module Seeding
  class Mapping
    def self.client_root
      raw = Rails.application.config.x.storage[:deluge_payload]
      raise Failure.new(:mapping) if raw.blank? || raw.match?(/[\\\x00-\x1f\x7f]/)

      path = Pathname.new(raw)
      raise Failure.new(:mapping) unless path.absolute? && path.cleanpath.to_s == raw

      raw
    end
  end
end
