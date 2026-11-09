require 'cgi'

module Content
  class Render
    Result = Data.define(:html, :errors)
    SIMPLE = { 'b' => 'strong', 'i' => 'em', 'u' => 'u', 's' => 's', 'quote' => 'blockquote', 'table' => 'div',
      'h1' => 'h1', 'h2' => 'h2', 'h3' => 'h3', 'h4' => 'h4', 'h5' => 'h5', '*' => 'li' }.freeze
    SPECIAL = { 'img' => :image, 'url' => :link, 'code' => :code, 'list' => :list, 'spoiler' => :spoiler,
      'color' => :styled, 'size' => :styled, 'font' => :styled, 'youtube' => :youtube, 'hr' => :rule }.freeze

    def self.call(source:, cover_url: nil)
      new(source, cover_url).call
    end

    def initialize(source, cover_url)
      @parsed = Bbcode.call(source: source)
      @cover_url = cover_url
    end

    def call
      html = children(@parsed.nodes)
      sanitized = ActionController::Base.helpers.sanitize(html,
        tags: %w[strong em u s div span blockquote pre code ul ol li details summary a img br hr h1 h2 h3 h4 h5],
        attributes: %w[href src alt class style rel target loading referrerpolicy])
      Result.new(html: sanitized, errors: (@parsed.errors + Attributes.errors(@parsed.nodes)).uniq)
    end

    private

    def children(nodes, parent: nil)
      nodes.map { |node| node.is_a?(String) ? text(node).gsub("\n", '<br>') : render_node(node, parent) }.join
    end

    def render_node(node, parent)
      return node_children(node) if Attributes.errors([ node ], parent: parent).any?
      return element(SIMPLE.fetch(node.tag), node_children(node)) if SIMPLE.key?(node.tag)
      send(SPECIAL.fetch(node.tag, :aligned), node)
    end

    def aligned(node)
      element('div', node_children(node), class: "bb-#{node.tag}")
    end

    def node_children(node)
      children(node.children, parent: node.tag)
    end

    def element(tag, body, attributes = {})
      attrs = attributes.map { |key, value| " #{key}=\"#{ERB::Util.html_escape(value)}\"" }.join
      "<#{tag}#{attrs}>#{body}</#{tag}>"
    end

    def text(value)
      ERB::Util.html_escape(CGI.unescapeHTML(value.to_s))
    end

    def image(node)
      url = node.children.join
      return element('span', text(I18n.t('content.preview.image_pending')), class: 'bb-image-placeholder') unless url == @cover_url && Providers::C411::EbookContent.safe_url?(url)

      %(<img src="#{ERB::Util.html_escape(url)}" alt="#{ERB::Util.html_escape(I18n.t('content.preview.cover'))}" loading="lazy" referrerpolicy="no-referrer">)
    end

    def link(node)
      href = node.argument || node.children.grep(String).join
      element('a', node_children(node), href: href, target: '_blank', rel: 'noopener noreferrer')
    end

    def code(node)
      element('pre', element('code', text(node.children.join)))
    end

    def list(node)
      tag = node.argument ? 'ol' : 'ul'
      element(tag, node_children(node))
    end

    def spoiler(node)
      element('details', element('summary', text(node.argument || I18n.t('content.preview.spoiler'))) + node_children(node))
    end

    def styled(node)
      property = { 'color' => 'color', 'size' => 'font-size', 'font' => 'font-family' }.fetch(node.tag)
      value = node.tag == 'size' ? "#{node.argument.to_i}px" : node.argument
      element('span', node_children(node), style: "#{property}:#{value}")
    end

    def youtube(node)
      element('a', text(I18n.t('content.preview.youtube')), href: "https://www.youtube.com/watch?v=#{node.children.join}", target: '_blank', rel: 'noopener noreferrer')
    end

    def rule(_node)
      '<hr>'
    end
  end
end
