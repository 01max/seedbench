module Covers
  class Workspace
    State = Data.define(:selected, :candidates, :values)

    def self.call(release:)
      payload_id = release.payload_revisions.order(number: :desc).pick(:id)
      evidence = release.evidence_items.where(payload_revision_id: payload_id, kind: %w[inspection edition_record]).order(id: :desc).limit(20)
      candidates = evidence.flat_map { |item| embedded(item) + online(item) }.first(30)
      State.new(selected: release.cover_revisions.order(number: :desc).first, candidates: candidates,
        values: Releases::EditorValues.call(release: release))
    end

    class << self
      private

      def embedded(item)
        Array(item.data['covers']).first(10).map do |image|
          { source: "embedded:#{item.id}:#{image.fetch('sha256')}", kind: 'embedded', evidence: item,
            width: image['width'], height: image['height'], sha256: image['sha256'] }
        end
      end

      def online(item)
        Array(item.data['cover_ids']).first(5).map do |id|
          { source: "online:#{item.id}:#{id}", kind: 'online', evidence: item,
            url: "https://covers.openlibrary.org/b/id/#{id}-L.jpg?default=false" }
        end
      end
    end
  end
end
