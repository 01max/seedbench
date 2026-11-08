module Releases
  class EventMetadata
    class Unsafe < StandardError; end
    SENSITIVE_KEY = /password|token|secret|api[_-]?key|passkey|credential/i

    def self.validate!(data)
      raise Unsafe, "Event metadata must contain only bounded, non-secret JSON values." unless
        data.is_a?(Hash) && safe?(data) && JSON.generate(data).bytesize <= 16_384
    rescue JSON::GeneratorError
      raise Unsafe, "Event metadata must be valid JSON."
    end

    def self.safe?(value, depth = 0)
      return false if depth > 8

      return safe_hash?(value, depth) if value.is_a?(Hash)
      return value.all? { |item| safe?(item, depth + 1) } if value.is_a?(Array)

      safe_scalar?(value)
    end
    private_class_method :safe?

    def self.safe_hash?(value, depth)
      value.all? { |key, item| safe_key?(key) && safe?(item, depth + 1) }
    end
    private_class_method :safe_hash?

    def self.safe_scalar?(value)
      return !value.match?(%r{https?://}i) if value.is_a?(String)

      [ Integer, Float, TrueClass, FalseClass, NilClass ].any? { |type| value.is_a?(type) }
    end
    private_class_method :safe_scalar?

    def self.safe_key?(key)
      (key.is_a?(String) || key.is_a?(Symbol)) && key.to_s.match?(/\A[a-z][a-z0-9_]{0,79}\z/) && !key.to_s.match?(SENSITIVE_KEY)
    end
    private_class_method :safe_key?
  end
end
