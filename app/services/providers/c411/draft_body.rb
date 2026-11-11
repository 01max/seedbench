module Providers
  class C411
    class DraftBody
      class << self
        def call(write:)
          content = write.request.fetch('content').except('nfo')
          return unlinked(write, content) unless write.request['payload_id']
          content.merge(linked(write))
        end

        private

        def linked(write)
          release = write.release
          preparation = release.preparation_revisions.order(number: :desc).first!
          category = category(write, preparation)
          category.merge('isAutosave' => false).merge(torrent_attachment(preparation),
            DraftAttachment.fields('nfo', "#{preparation.release_name}.nfo", write.request.fetch('content').fetch('nfo')))
        end

        def category(write, preparation)
          category = DraftCategory.call(connection: write.provider_connection, format: preparation.payload_revision.format)
          return category unless write.action == 'update'
          data = Drafts.new(write.provider_connection).read(write.remote_id)
          options = data['options'] || {}
          raise ::Drafts::Failure.new(:invalid_response) unless options.is_a?(Hash)
          category.merge('options' => options.merge(category.fetch('options')))
        end

        def torrent_attachment(preparation)
          torrent = Preparation::Paths.new.path(preparation.torrent_locator, kind: :state).binread
          DraftAttachment.fields('torrent', preparation.torrent_locator.split('/').last, torrent)
        end

        def unlinked(write, content)
          base = write.release.remote_snapshots.where(kind: 'draft', remote_id: write.remote_id).order(:id).last!.base_content
          nfo = write.request.fetch('content').fetch('nfo')
          return content if nfo == base.fetch('nfo', '')
          content.merge(DraftAttachment.fields('nfo', nfo.empty? ? nil : 'draft.nfo', nfo.presence))
        end
      end
    end
  end
end
