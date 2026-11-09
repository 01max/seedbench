module Ebooks
  class Request
    class << self
      def call(release:, ocr: false, automatic: false)
        release.with_lock { start(release, ocr, automatic) }
      end

      private

      def start(release, ocr, automatic)
        payload = release.payload_revisions.order(number: :desc).first!
        key = automatic ? "inspection-#{payload.id}-#{release.input_revision}-#{ocr ? 'ocr' : 'text'}" : SecureRandom.uuid
        operation = Workflows::Start.call(release_id: release.id, kind: "inspection", request_key: key,
          expected_revision: release.input_revision, parameters: { payload_revision_id: payload.id, ocr: ocr })
        release.update!(inspection_state: "pending") if operation.state == "pending"
        operation
      end
    end
  end
end
