module Covers
  class Failure < StandardError
    attr_reader :code

    def initialize(code)
      @code = code.to_s
      super(I18n.t("covers.errors.#{code}"))
    end
  end
end
