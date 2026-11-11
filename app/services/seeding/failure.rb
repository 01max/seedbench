module Seeding
  class Failure < StandardError
    attr_reader :code, :progress

    def initialize(code, progress: nil)
      @code, @progress = code.to_s, progress
      super(I18n.t("seeding.errors.#{code}"))
    end
  end
end
