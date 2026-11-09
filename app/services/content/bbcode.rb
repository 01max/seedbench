require 'strscan'

module Content
  class Bbcode
    Node = Data.define(:tag, :argument, :children)
    Result = Data.define(:nodes, :errors)
    class Limit < StandardError; end
    TOKEN = /\[(\/?)([a-z][a-z0-9]*|\*)(?:=([^\]\r\n]{1,2000}))?\]/i

    def self.call(source:)
      new(source).call
    end

    def initialize(source)
      @source = source
      @scanner = StringScanner.new(source)
      @root = Node.new(tag: 'root', argument: nil, children: [])
      @stack, @errors, @count = [ @root ], [], 0
    end

    def call
      raise Limit if @source.length > 250_000

      consume until @scanner.eos?
      @errors << 'unclosed_tag' unless @stack.size == 1
      Result.new(nodes: @root.children, errors: @errors.uniq)
    rescue Limit
      Result.new(nodes: [ @source.first(15_000) ], errors: [ 'markup_limit' ])
    end

    private

    def consume
      @count += 1
      raise Limit if @count > 4000 || @stack.size > 32

      if @scanner.scan(TOKEN)
        token(@scanner[1], @scanner[2].downcase, @scanner[3], @scanner.matched)
      else
        plain_text
      end
    end

    def plain_text
      chunk = @scanner.scan(/[^\[]+/)
      @errors << 'unsupported_tag' unless chunk
      @stack.last.children << (chunk || @scanner.getch)
    end

    def token(closing, tag, argument, literal)
      unless Providers::C411::EbookContent::TAGS.include?(tag)
        @errors << 'unsupported_tag'
        return @stack.last.children << literal
      end
      check_argument(closing, tag, argument)
      return close(tag, literal) if closing == '/'
      return code if tag == 'code'

      @stack.pop if tag == '*' && @stack.last.tag == '*'
      node = Node.new(tag: tag, argument: argument, children: [])
      @stack.last.children << node
      @stack << node unless tag == 'hr'
    end

    def check_argument(closing, tag, argument)
      @errors << 'invalid_attribute' if argument && (closing == '/' || tag == 'code')
    end

    def close(tag, literal)
      @stack.pop if tag == 'list' && @stack.last.tag == '*'
      if @stack.size > 1 && @stack.last.tag == tag
        @stack.pop
      else
        @errors << 'invalid_nesting'
        @stack.last.children << literal
      end
    end

    def code
      text = @scanner.scan_until(/\[\/code\]/i)
      @errors << 'unclosed_tag' unless text
      @stack.last.children << Node.new(tag: 'code', argument: nil, children: [ text ? text.sub(/\[\/code\]\z/i, '') : @scanner.rest ])
      @scanner.terminate unless text
    end
  end
end
