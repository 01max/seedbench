module Covers
  class HostedImage
    class << self
      def direct_link(page_url:)
        page = Fetch.call(url: page_url, max_bytes: 256.kilobytes, hosts: [ 'postimg.cc' ])
        value = Nokogiri::HTML5(page.bytes).at_css('input#direct')&.[]('value')
        validate_url!(value)
        value
      end

      def verify(url:, source:, cover:)
        validate_url!(url)
        result = Fetch.call(url: url, hosts: [ 'i.postimg.cc' ])
        image = Image.call(bytes: result.bytes)
        raise Failure.new(:hosted_image) unless result.media_type == image.fetch('media_type')

        proof = compare(source, image)
        image.merge('verification' => proof.merge('policy' => Policy::VERSION, 'source_sha256' => source.fetch('sha256'),
          'edition_fingerprint' => Policy.fingerprint(cover)))
      end

      private

      def validate_url!(url)
        uri = URI.parse(url.to_s)
        raise Failure.new(:hosted_image) unless uri.scheme == 'https' && uri.host == 'i.postimg.cc' && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      rescue URI::InvalidURIError
        raise Failure.new(:hosted_image), cause: nil
      end

      def verify_dimensions!(source, hosted)
        original_ratio = source.fetch('width').fdiv(source.fetch('height'))
        hosted_ratio = hosted.fetch('width').fdiv(hosted.fetch('height'))
        raise Failure.new(:hosted_mismatch) if (original_ratio - hosted_ratio).abs / original_ratio > 0.03

        %w[width height].each do |axis|
          scale = hosted.fetch(axis).fdiv(source.fetch(axis))
          raise Failure.new(:hosted_mismatch) unless (0.8..1.05).cover?(scale)
        end
      end

      def compare(source, hosted)
        verify_dimensions!(source, hosted)
        differences = source.fetch('grid').zip(hosted.fetch('grid')).sum { |left, right| (left - right).abs }
        difference = differences.fdiv(1152 * 255)
        raise Failure.new(:hosted_mismatch) if difference > 0.08

        { 'mean_pixel_difference' => difference, 'hosted_sha256' => hosted.fetch('sha256') }
      end
    end
  end
end
