module Covers
  # Carries a localized error and stable code for failures in cover selection or hosting.
  class Failure < StandardError
    attr_reader :code

    def initialize(code)
      @code = code.to_s
      super(I18n.t("covers.errors.#{code}"))
    end
  end
end
