module Providers
  # Carries a sanitized provider error and stable code for workflow callers.
  class Failure < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
