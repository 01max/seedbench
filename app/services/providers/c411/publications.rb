require 'stringio'

module Providers
  class C411
    class Publications
      Receipt = Data.define(:id, :info_hash, :status)
      HASH = /\A[0-9a-f]{40}\z/
      STATUS = /\A[a-z][a-z_]{0,39}\z/

      def initialize(connection)
        @connection = connection
      end

      def submit(fields:, torrent:, nfo:, name:)
        parts = fields.to_a + [
          [ 'torrent', StringIO.new(torrent), { filename: "#{name}.torrent", content_type: 'application/x-bittorrent' } ],
          [ 'nfo', StringIO.new(nfo), { filename: "#{name}.nfo", content_type: 'application/octet-stream' } ]
        ]
        response = Http.call(endpoint: @connection.endpoint, path: '/api/torrents', headers: headers,
          multipart: parts, total_timeout: 25, read_timeout: 15)
        data = Http.json(response)
        raise invalid_response unless data.is_a?(Hash) && data['success'] == true

        receipt(data['data'])
      end

      private

      def receipt(value)
        raise invalid_response unless value.is_a?(Hash)

        id, hash, status = value.values_at('id', 'infoHash', 'status')
        raise invalid_response unless id.is_a?(Integer) && id.positive? && HASH.match?(hash.to_s) && STATUS.match?(status.to_s)

        Receipt.new(id: id, info_hash: hash, status: status)
      end

      def headers
        { 'Authorization' => "Bearer #{@connection.credentials.fetch('api_key')}", 'Accept' => 'application/json' }
      end

      def invalid_response
        Failure.new('invalid_response', I18n.t('publication.errors.invalid_response'))
      end
    end
  end
end
