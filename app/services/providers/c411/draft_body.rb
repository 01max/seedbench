module Providers
  class C411
    class DraftBody
      class << self
        def call(write:)
          content = write.request.fetch('content').except('nfo')
          return unlinked(write, content) unless write.request['payload_id']
          content.merge(linked(write))
        end

        def preserve_options(body, data)
          return body unless body.key?('options')

          options = data['options'] || {}
          raise ::Drafts::Failure.new(:invalid_response) unless options.is_a?(Hash)
          body.merge('options' => options.merge(body.fetch('options')))
        end

        def matches?(body, data)
          return false unless data

          fields = body.except('torrentFileName', 'torrentFileData', 'nfoFileName', 'nfoFileData')
          data.slice(*fields.keys) == fields && %w[torrent nfo].all? { |kind| DraftAttachment.matches?(kind, body, data) }
        end

        private

        def linked(write)
          release = write.release
          preparation = release.preparation_revisions.order(number: :desc).first!
          category = DraftCategory.call(connection: write.provider_connection, format: preparation.payload_revision.format)
          category.merge('isAutosave' => false).merge(torrent_attachment(preparation),
            DraftAttachment.fields('nfo', "#{preparation.release_name}.nfo", write.request.fetch('content').fetch('nfo')))
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
