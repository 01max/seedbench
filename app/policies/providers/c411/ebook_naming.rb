module Providers
  class C411
    class EbookNaming
      class InvalidName < StandardError; end
      Names = Data.define(:release, :payload, :torrent)
      VERSION = 'c411-ebook-naming-v1'.freeze
      FORMATS = %w[epub pdf mobi].freeze

      class << self
        def call(title:, author:, language:, format:, team: 'NOTAG')
          invalid! unless %w[fr fra french français francais].include?(language.to_s.downcase)

          base = [ words(title), words(author), 'FRENCH' ].join('.')
          names(base, format, team)
        end

        def from_release(name:, format:)
          match = name.to_s.match(/\A(.+)\.\[(EPUB|PDF|MOBI)\]-([a-zA-Z0-9]+)\z/i)
          invalid! unless match && match[2].downcase == format

          base = match[1]
          base = base.sub(/(?:[.-]NOTAG|\.VFF)+\z/i, '') if base.match?(/[.-]NOTAG(?:\.|-|\z)/i)
          names(base, format, match[3])
        end

        private

        def words(value)
          result = value.to_s.unicode_normalize(:nfc).scan(/[\p{L}\p{N}]+/).join('.')
          invalid! if result.empty?
          result
        end

        def names(base, format, team)
          invalid! unless FORMATS.include?(format) && team.to_s.match?(/\A[a-zA-Z0-9]{1,24}\z/)
          validate_base!(base)

          team = 'NOTAG' if team.casecmp?('notag')
          release = "#{base}.[#{format.upcase}]-#{team}"
          invalid! if release.length > 200 || release.bytesize > 230

          Names.new(release: release, payload: "#{base}-#{team}.#{format}", torrent: "#{base}.#{team}.torrent")
        end

        def validate_base!(base)
          invalid! unless base.match?(/\A[\p{L}\p{N}]+(?:\.[\p{L}\p{N}]+)*\z/)
          invalid! if base.split('.').any? { |part| %w[VFF VFI MULTI 1080p 720p WEBRip BluRay].include?(part) }
        end

        def invalid!
          raise InvalidName, I18n.t('preparation.errors.invalid_name')
        end
      end
    end
  end
end
