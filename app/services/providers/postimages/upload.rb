require 'base64'

module Providers
  class Postimages
    class Upload
      PAGE = %r{https://postimg\.cc/[A-Za-z0-9]+}.freeze

      def self.call(connection:, bytes:, media_type:, name:)
        fields = { key: connection.credentials.fetch('api_key'), o: '2b819584285c102318568238c7d4a4c7', m: '59c2ad4b46b0c1e12d5703302bff0120',
          version: '1.0.1', portable: '1', name: name, type: { 'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp' }.fetch(media_type),
          image: Base64.strict_encode64(bytes) }
        response = Http.call(endpoint: 'https://api.postimage.org', path: '/1/upload', form: fields)
        page = CGI.unescapeHTML(response.body.gsub('\\/', '/'))[PAGE]
        raise Covers::Failure.new(:upload_unknown) unless page

        page
      end
    end
  end
end
