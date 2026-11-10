module Ai
  class SchemaValidation
    TYPES = { 'object' => Hash, 'array' => Array, 'string' => String, 'null' => NilClass }.freeze

    def self.call(value:, schema:)
      new(schema).valid?(value, schema)
    end

    def initialize(schema)
      @definitions = schema.fetch('$defs')
    end

    def valid?(value, schema)
      schema = @definitions.fetch(schema.fetch('$ref').split('/').last) if schema['$ref']
      return false unless scalar?(value, schema)
      return object?(value, schema) if value.is_a?(Hash)
      return value.all? { |item| valid?(item, schema.fetch('items')) } if value.is_a?(Array)

      true
    end

    private

    def scalar?(value, schema)
      Array(schema.fetch('type')).any? { |type| value.is_a?(TYPES.fetch(type)) } &&
        (!schema['enum'] || schema['enum'].include?(value))
    end

    def object?(value, schema)
      value.keys.all?(String) && value.keys.sort == schema.fetch('required').sort &&
        value.all? { |key, item| valid?(item, schema.fetch('properties').fetch(key)) }
    end
  end
end
