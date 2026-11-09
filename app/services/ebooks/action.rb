module Ebooks
  class Action
    class UnknownAction < StandardError; end

    def self.call(release_id:, kind:, expected_revision:, isbn: nil)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        case kind
        when 'inspect', 'ocr'
          raise UnknownAction, I18n.t('ebooks.unknown_action') if kind == 'ocr' && release.payload_revisions.order(number: :desc).pick(:format) != 'pdf'

          Request.call(release: release, ocr: kind == 'ocr')
        when 'lookup' then RequestLookup.call(release: release, isbn: isbn)
        else raise UnknownAction, I18n.t('ebooks.unknown_action')
        end
      end
    end
  end
end
