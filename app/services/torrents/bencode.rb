module Torrents
  class Bencode
    class Invalid < StandardError; end
    MAX_BYTES = 10 * 1024 * 1024

    def self.decode(bytes)
      new(bytes).decode
    end

    class << self
      def encode(value)
        case value
        when Integer then "i#{value}e".b
        when String then "#{value.bytesize}:".b + value.b
        when Array then encode_list(value)
        when Hash then encode_dictionary(value)
        else raise Invalid
        end
      end

      private

      def encode_list(value)
        'l'.b + value.map { |item| encode(item) }.join.b + 'e'.b
      end

      def encode_dictionary(value)
        entries = value.sort_by { |key, _| key.b }.map { |key, item| encode(key) + encode(item) }.join.b
        'd'.b + entries + 'e'.b
      end
    end

    def initialize(bytes)
      raise Invalid unless bytes.is_a?(String) && bytes.bytesize.between?(1, MAX_BYTES)

      @bytes, @offset, @nodes = bytes.b, 0, 0
    end

    def decode
      result = read(0)
      raise Invalid unless @offset == @bytes.bytesize

      result
    rescue ArgumentError, IndexError, NoMethodError
      raise Invalid
    end

    private

    def read(depth)
      @nodes += 1
      raise Invalid if depth > 16 || @nodes > 1024 || @offset >= @bytes.bytesize

      case @bytes.getbyte(@offset)
      when 105 then integer
      when 100 then dictionary(depth)
      when 108 then list(depth)
      else string
      end
    end

    def integer
      finish = @bytes.index('e', @offset) || raise(Invalid)
      text = @bytes.byteslice((@offset + 1)...finish)
      raise Invalid unless text.match?(/\A(?:0|-?[1-9]\d{0,18})\z/)

      @offset = finish + 1
      Integer(text, 10)
    end

    def string
      separator = @bytes.index(':', @offset) || raise(Invalid)
      length = @bytes.byteslice(@offset...separator)
      raise Invalid unless length.match?(/\A(?:0|[1-9]\d{0,7})\z/)

      start = separator + 1
      @offset = start + Integer(length, 10)
      raise Invalid if @offset > @bytes.bytesize

      @bytes.byteslice(start...@offset)
    end

    def list(depth)
      @offset += 1
      result = []
      result << read(depth + 1) until @bytes.getbyte(@offset) == 101
      @offset += 1
      result
    end

    def dictionary(depth)
      @offset += 1
      result = {}
      previous = nil
      until @bytes.getbyte(@offset) == 101
        key = string
        raise Invalid if previous && key <= previous

        result[key] = read(depth + 1)
        previous = key
      end
      @offset += 1
      result
    end
  end
end
