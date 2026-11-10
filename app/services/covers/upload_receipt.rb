module Covers
  class UploadReceipt
    class << self
      def call(context:, bytes:, image:)
        existing = previous(context)
        return reuse(existing) if existing

        upload = create_intent(context, image)
        page = Providers::Postimages::Upload.call(connection: context.connection, bytes: bytes, media_type: image.fetch('media_type'), name: "cover-#{context.cover.id}")
        upload.update!(page_url: page, state: 'uploaded', failure_code: nil)
        upload
      rescue Providers::Failure, Failure => error
        uncertain(upload, error) if upload
        raise
      rescue ActiveRecord::RecordNotUnique
        raise Failure.new(:upload_unknown)
      end

      private

      def previous(context)
        CoverUpload.where(release_id: context.operation.release_id, cover_revision_id: context.cover.id,
          provider_connection_id: context.connection.id).order(:id).last
      end

      def create_intent(context, image)
        CoverUpload.create!(release_id: context.operation.release_id, workflow_operation_id: context.operation.id,
          cover_revision_id: context.cover.id, provider_connection_id: context.connection.id, source_sha256: image.fetch('sha256'))
      end

      def reuse(upload)
        raise Failure.new(:upload_unknown) unless upload.page_url && upload.state != 'outcome_unknown'

        upload
      end

      def uncertain(upload, error)
        upload.update!(state: 'outcome_unknown', failure_code: error.code)
      end
    end
  end
end
