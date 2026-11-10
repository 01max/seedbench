module Drafts
  class Content
    FIELDS = { 'name' => 'proposed_name', 'title' => 'title', 'description' => 'bbcode', 'nfo' => 'nfo' }.freeze

    class << self
      def remote(data)
        values = FIELDS.except('nfo').each_key.index_with do |field|
          value = data[field].to_s
          raise Failure.new(:invalid_response) unless value.valid_encoding? && value.length <= limit(field)
          value
        end
        values.merge('nfo' => Providers::C411::DraftAttachment.nfo(data['nfoFile']))
      end

      def local(release)
        values = Releases::EditorValues.call(release: release)
        FIELDS.transform_values { |field| values.fetch(field) }.transform_keys(&:to_s)
      end

      def adopt(release, content)
        changes = content.transform_keys { |field| FIELDS.fetch(field) }
        Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: changes)
      end

      private

      def limit(field)
        Releases::Save::LIMITS.fetch(FIELDS.fetch(field))
      end
    end
  end
end
