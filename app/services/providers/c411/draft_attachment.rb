require 'base64'

module Providers
  class C411
    class DraftAttachment
      class << self
        def nfo(data)
          return '' if data.nil?
          raise ::Drafts::Failure.new(:invalid_response) unless data.is_a?(Hash) && data['data'].is_a?(String)
          text = Base64.strict_decode64(data.fetch('data')).force_encoding(Encoding::UTF_8)
          raise ::Drafts::Failure.new(:invalid_response) unless text.valid_encoding? && text.length <= Releases::Save::LIMITS.fetch('nfo')
          text
        rescue ArgumentError
          raise ::Drafts::Failure.new(:invalid_response), cause: nil
        end

        def fields(kind, name, bytes)
          { "#{kind}FileName" => name, "#{kind}FileData" => bytes.nil? ? nil : Base64.strict_encode64(bytes) }
        end

      end
    end
  end
end
