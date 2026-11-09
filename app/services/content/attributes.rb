module Content
  class Attributes
    Policy = Providers::C411::EbookContent
    FONTS = %w[Arial Verdana Georgia monospace serif sans-serif].freeze

    RULES = { 'img' => :image?, 'url' => :link?, 'color' => :color?, 'size' => :size?, 'font' => :font?,
      'youtube' => :youtube?, '*' => :item? }.freeze

    class << self
      def errors(nodes, parent: nil)
        nodes.grep(Bbcode::Node).flat_map do |node|
          own = valid?(node, parent) ? [] : [ 'invalid_attribute' ]
          own + errors(node.children, parent: node.tag)
        end.uniq
      end

      private

      def valid?(node, parent)
        send(RULES.fetch(node.tag, :standard?), node, parent)
      end

      def image?(node, _parent)
        node.argument.nil? && node.children.all?(String) && Policy.safe_url?(node.children.join)
      end

      def link?(node, parent)
        parent != 'url' && Policy.safe_url?(node.argument || node.children.grep(String).join)
      end

      def color?(node, _parent)
        node.argument.to_s.match?(/\A(?:#[0-9a-f]{3}(?:[0-9a-f]{3})?|red|blue|green|black|white|purple|orange|gray)\z/i)
      end

      def size?(node, _parent)
        node.argument.to_s.match?(/\A\d{1,2}\z/) && node.argument.to_i.between?(8, 48)
      end

      def font?(node, _parent)
        FONTS.include?(node.argument)
      end

      def youtube?(node, _parent)
        node.argument.nil? && node.children.join.match?(/\A[a-zA-Z0-9_-]{11}\z/)
      end

      def item?(node, parent)
        parent == 'list' && node.argument.nil?
      end

      def standard?(node, _parent)
        return node.argument.nil? || %w[1 a].include?(node.argument) if node.tag == 'list'
        return node.argument.nil? || node.argument.length <= 200 if %w[quote spoiler].include?(node.tag)

        node.argument.nil?
      end
    end
  end
end
