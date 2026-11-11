module Publications
  class Failure < StandardError
    attr_reader :codes

    def initialize(*codes)
      @codes = codes.flatten.map(&:to_s)
      super(@codes.map { |code| I18n.t("publication.errors.#{code}") }.join(' '))
    end
  end
end
