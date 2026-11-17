require 'base64'

module Providers
  class Postimages
    # Uploads reviewed cover bytes to Postimages and returns the validated image page URL.
    class Upload
      PAGE = %r{\Ahttps://postimg\.cc/[A-Za-z0-9]+\z}.freeze

      class << self
        def call(connection:, bytes:, media_type:, name:)
          fields = { key: connection.credentials.fetch('api_key'), o: '2b819584285c102318568238c7d4a4c7', m: '59c2ad4b46b0c1e12d5703302bff0120',
            version: '1.0.1', portable: '1', name: name, type: { 'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp' }.fetch(media_type),
            image: Base64.strict_encode64(bytes) }
          response = Http.call(endpoint: 'https://api.postimage.org', path: '/1/upload', form: fields)
          page = upload_page(response.body)
          raise Covers::Failure.new(:upload_unknown) unless page.is_a?(String) && PAGE.match?(page)

          page
        rescue JSON::ParserError, Nokogiri::XML::SyntaxError
          raise Covers::Failure.new(:upload_unknown), cause: nil
        end

        private

        def upload_page(body)
          return xml_page(body) unless body.lstrip.start_with?('{')

          data = JSON.parse(body)
          data['url'] if [ true, 1, '1' ].include?(data['success'])
        end

        def xml_page(body)
          document = Nokogiri::XML(body) { |config| config.strict.nonet }
          return if document.internal_subset

          document.at_xpath('/data[@success="1"]/url')&.text
        end
      end
    end
  end
end
