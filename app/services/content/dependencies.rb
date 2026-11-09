require 'digest'

module Content
  class Dependencies
    def self.call(inputs:, values:, kind:)
      new(inputs, values, kind).call
    end

    def initialize(inputs, values, kind)
      @inputs, @values, @kind = inputs, values, kind
    end

    def call
      { 'policy_version' => Providers::C411::EbookContent::VERSION,
        'fingerprint' => Digest::SHA256.hexdigest(JSON.generate(material)), 'material' => material, **provenance }
    end

    private

    def material
      values = @values.except('cover')
      values = values.except('presentation') if @kind == 'nfo'
      values.merge!(technical)
      values['cover'] = [ @inputs.cover&.id, @inputs.hosting&.direct_url ] if @kind == 'bbcode'
      values['preparation'] = [ @inputs.preparation&.id, @inputs.prepared? ] if @kind == 'nfo'
      values
    end

    def provenance
      { 'facts' => @inputs.facts.transform_values(&:id), 'payload_revision_id' => @inputs.payload&.id,
        'preparation_revision_id' => @inputs.preparation&.id, 'cover_revision_id' => @inputs.cover&.id,
        'inspection_evidence_id' => @inputs.inspection&.id }
    end

    def technical
      { 'payload' => @inputs.payload&.slice('id', 'sha256', 'size_bytes', 'format'), 'inspected' => !!@inputs.inspected?,
        'counts' => @kind == 'nfo' ? @inputs.structure.slice('page_count', 'spine_documents') : {} }
    end
  end
end
