module Ebooks
  class RequestLookup
    def self.call(release:, isbn:)
      raise EditionRecord::InvalidIsbn, I18n.t('ebooks.review.invalid_isbn') unless Isbn.valid?(isbn)

      payload = release.payload_revisions.order(number: :desc).first!
      Workflows::Start.call(release_id: release.id, kind: 'edition_lookup', request_key: SecureRandom.uuid,
        expected_revision: release.input_revision, parameters: { payload_revision_id: payload.id, isbn: Isbn.normalize(isbn) })
    end
  end
end
