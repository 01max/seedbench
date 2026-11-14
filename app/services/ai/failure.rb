module Ai
  # Carries a localized error and stable code for failures callers can handle in the AI workflow.
  class Failure < StandardError
    attr_reader :code

    def initialize(code)
      @code = code.to_s
      super(I18n.t("ai.errors.#{code}"))
    end
  end
end
