module Duplicates
  class Failure < StandardError
    attr_reader :code

    def initialize(code)
      @code = code.to_s
      super(I18n.t("duplicates.errors.#{code}"))
    end
  end
end
