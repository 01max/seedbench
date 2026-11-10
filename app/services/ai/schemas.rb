module Ai
  class Schemas
    SCHEMAS = %w[assessment prose].index_with { |purpose| Rails.root.join('config/ai', "#{purpose}.schema.json").read }.freeze

    def self.call(purpose:, evidence_ids:)
      schema = JSON.parse(SCHEMAS.fetch(purpose))
      schema.fetch('$defs').fetch('citations').fetch('items')['enum'] = evidence_ids.uniq
      schema
    end
  end
end
