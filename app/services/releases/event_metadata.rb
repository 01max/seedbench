module Releases
  class EventMetadata
    class Unsafe < StandardError; end
    SENSITIVE_KEY = /password|token|secret|api[_-]?key|passkey|credential/i

    class << self
      def validate!(data)
        raise Unsafe, I18n.t('messages.releases.event_metadata.event_metadata_must_contain_only_bounded') unless
          data.is_a?(Hash) && safe?(data) && JSON.generate(data).bytesize <= 16_384
      rescue JSON::GeneratorError
        raise Unsafe, I18n.t('messages.releases.event_metadata.event_metadata_must_be_valid_json')
      end

      private

      def safe?(value, depth = 0)
        return false if depth > 8

        return safe_hash?(value, depth) if value.is_a?(Hash)
        return value.all? { |item| safe?(item, depth + 1) } if value.is_a?(Array)

        safe_scalar?(value)
      end

      def safe_hash?(value, depth)
        value.all? { |key, item| safe_key?(key) && safe?(item, depth + 1) }
      end

      def safe_scalar?(value)
        return !value.match?(%r{https?://}i) if value.is_a?(String)

        [ Integer, Float, TrueClass, FalseClass, NilClass ].any? { |type| value.is_a?(type) }
      end

      def safe_key?(key)
        (key.is_a?(String) || key.is_a?(Symbol)) && key.to_s.match?(/\A[a-z][a-z0-9_]{0,79}\z/) && !key.to_s.match?(SENSITIVE_KEY)
      end
    end
  end
end
