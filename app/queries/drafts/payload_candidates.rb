module Drafts
  class PayloadCandidates
    Result = Data.define(:records, :proposed_ids)

    class << self
      def call(release:, query: '')
        scope = Release.includes(:payload_revisions).where.not(id: DraftLink.select(:release_id))
          .where(id: PayloadRevision.select(:release_id), publication_state: 'unpublished')
        matches = matching(scope, query.to_s.first(200).presence || release.title)
        records = query.present? ? matches : matches.first(20) + others(scope, matches)
        Result.new(records: records, proposed_ids: matches.map(&:id))
      end

      private

      def matching(scope, text)
        return [] if text.blank?
        term = "%#{Release.sanitize_sql_like(Releases::SearchText.call(title: text))}%"
        scope.where("search_text LIKE ? ESCAPE '\\'", term).order(:id).limit(100).to_a
      end

      def others(scope, matches)
        scope.where.not(id: matches.first(20).map(&:id)).order(:id).limit(80).to_a
      end
    end
  end
end
