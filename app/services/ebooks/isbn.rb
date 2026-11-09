module Ebooks
  class Isbn
    def self.normalize(value)
      value.to_s.sub(/\A(?:urn:)?isbn:?\s*/i, "").gsub(/[[:space:]-]/, "").upcase
    end

    def self.valid?(value)
      isbn = normalize(value)
      return isbn.start_with?("978", "979") && checksum13(isbn).zero? if isbn.match?(/\A\d{13}\z/)
      return false unless isbn.match?(/\A\d{9}[\dX]\z/)

      isbn.chars.each_with_index.sum { |digit, index| (digit == "X" ? 10 : digit.to_i) * (10 - index) }.modulo(11).zero?
    end

    def self.canonical(value)
      return unless valid?(value)

      isbn = normalize(value)
      return isbn if isbn.length == 13

      prefix = "978#{isbn[0, 9]}"
      "#{prefix}#{(10 - checksum13("#{prefix}0")) % 10}"
    end

    def self.checksum13(isbn)
      isbn.chars.each_with_index.sum { |digit, index| digit.to_i * (index.even? ? 1 : 3) }.modulo(10)
    end
    private_class_method :checksum13
  end
end
