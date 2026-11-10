module Providers
  class C411
    class SearchFeed
      Result = Data.define(:candidates, :count, :total, :incomplete)
      NAMESPACE = 'http://torznab.com/schemas/2015/feed'.freeze

      class << self
        def call(body:)
          raise Duplicates::Failure.new(:invalid_response) if body.match?(/<!DOCTYPE/i)

          document = parse(body)
          items = document.xpath('/rss/channel/item')

          candidates = items.filter_map { |item| candidate(item) }
          total = document.at_xpath('//*[local-name()="response"]')&.[]('total')
          Result.new(candidates: candidates, count: items.size, total: Integer(total, exception: false), incomplete: candidates.size != items.size)
        rescue Nokogiri::XML::SyntaxError
          raise Duplicates::Failure.new(:invalid_response), cause: nil
        end

        private

        def parse(body)
          document = Nokogiri::XML(body) { |config| config.strict.nonet }
          raise Duplicates::Failure.new(:invalid_response) unless document.at_xpath('/rss/channel')

          document
        end

        def candidate(item)
          attributes = item.xpath('t:attr', 't' => NAMESPACE).to_h { |node| [ node['name'], node['value'] ] }
          hash = attributes['infohash'].to_s.downcase
          title = item.at_xpath('title')&.text.to_s.first(1000)
          return unless hash.match?(/\A[0-9a-f]{40}\z/) && title.present?

          evidence = evidence(item, title, attributes)
          evidence.merge('key' => Digest::SHA256.hexdigest(JSON.generate([ hash, evidence ])), 'info_hash' => hash,
            'url' => "https://c411.org/torrents/#{hash}")
        end

        def evidence(item, title, attributes)
          { 'title' => title, 'description' => plain(item.at_xpath('description')&.text),
            'format' => title.scan(/\b(?:EPUB|PDF|MOBI|AZW3?)\b/i).map(&:upcase).uniq,
            'size_bytes' => Integer(attributes['size'], exception: false) }
        end

        def plain(value)
          Nokogiri::HTML5.fragment(value.to_s.first(12_000)).text.gsub(%r{https?://\S+}, '').first(3000)
        end
      end
    end
  end
end
