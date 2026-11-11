module Drafts
  class Message
    def self.call(code:)
      return if code.blank?
      %w[drafts.errors covers.errors preparation.errors].each do |prefix|
        key = "#{prefix}.#{code}"
        return I18n.t(key) if I18n.exists?(key)
      end
      I18n.t('drafts.errors.provider_rejected', code: code)
    end
  end
end
