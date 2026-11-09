module Providers
  class C411
    class EbookContent
      VERSION = 'c411-ebook-2026-11-09-v1'.freeze
      MIN_COVER_WIDTH = 600
      MIN_COVER_HEIGHT = 900
      MAX_DESCRIPTION = 15_000
      TAGS = %w[b i u s url img color size quote code list youtube spoiler center left right font hr h1 h2 h3 h4 h5 table *].freeze
      FIELDS = %w[cover title author publisher publication_year digital_isbn language presentation files size notes].freeze
      LABELS = [ 'Auteur(s) :', 'Éditeur :', 'Parution :', 'ISBN numérique :', 'Langue :', 'Présentation :', 'Fichier(s) :', 'Taille :', 'Notes supplémentaire :' ].freeze
      TEMPLATE = Rails.root.join('config/c411/ebook.bbcode.txt').read.freeze
      PATTERN = Regexp.new("\\A#{Regexp.escape(TEMPLATE).gsub(/%\\\{(\w+)\\\}/) { "(?<#{$1}>.*?)" }}\\z", Regexp::MULTILINE)

      class << self
        def assemble(values:)
          format(TEMPLATE, **values.symbolize_keys.slice(*FIELDS.map(&:to_sym)))
        end

        def fields(body:)
          return unless LABELS.all? { |label| body.scan(Regexp.new(Regexp.escape(label))).size == 1 }

          PATTERN.match(body.gsub("\r\n", "\n"))&.named_captures
        end

        def escape(value)
          value.to_s.gsub('&', '&amp;').gsub('[', '&#91;').gsub(']', '&#93;')
        end

        def portrait_cover?(cover)
          cover && cover.width >= MIN_COVER_WIDTH && cover.height >= MIN_COVER_HEIGHT && cover.height >= cover.width
        end

        def safe_url?(value)
          return false if value.match?(/[\s\x00-\x1f\x7f]/)

          uri = URI.parse(value)
          %w[https http].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
