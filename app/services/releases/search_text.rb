module Releases
  class SearchText
    def self.call(title:, author: nil)
      [ title, author ].compact.join(' ').encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        .unicode_normalize(:nfkd).gsub(/\p{M}/, '').downcase.squish
    end
  end
end
