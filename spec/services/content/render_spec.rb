require 'rails_helper'

RSpec.describe Content::Render do
  it 'renders supported formatting, code and lists without executing HTML' do
    result = described_class.call(source: '[center][b]Titre[/b][/center][list][*]Un[*]Deux[/list][code]<script>bad()</script>[/code]')
    document = Nokogiri::HTML5.fragment(result.html)
    expect(document.at_css('.bb-center strong').text).to eq('Titre')
    expect(document.css('li').map(&:text)).to eq(%w[Un Deux])
    expect(document.at_css('pre code').text).to eq('<script>bad()</script>')
    expect(document.css('script')).to be_empty
  end

  it 'keeps unsafe links and unverified image destinations inert' do
    result = described_class.call(source: '[url=javascript:alert(1)]click[/url][img]https://untrusted.invalid/pixel[/img]<img src=x onerror=bad()>')
    document = Nokogiri::HTML5.fragment(result.html)
    expect(document.css('a,img,script')).to be_empty
    expect(result.errors).to include('invalid_attribute')
  end

  it 'loads only the exact selected verified cover and escapes literal brackets safely' do
    url = 'https://images.invalid/cover.png'
    html = described_class.call(source: "[img]#{url}[/img] &#91;b&#93;literal", cover_url: url).html
    document = Nokogiri::HTML5.fragment(html)
    expect(document.at_css('img')['src']).to eq(url)
    expect(document.text).to include('[b]literal')
    expect(document.css('strong')).to be_empty
  end

  it 'bounds deeply nested or oversized markup without changing its source' do
    source = ('[b]' * 1000) + 'content' + ('[/b]' * 1000)
    result = described_class.call(source: source)
    expect(result.errors).to include('markup_limit')
    expect(source).to start_with('[b]' * 1000)
    expect(described_class.call(source: 'x' * 250_001).errors).to include('markup_limit')
  end

  it 'rejects unsafe style attributes and keeps passive tags safe' do
    html = described_class.call(source: '[color=url(javascript:bad)]text[/color][spoiler=Lire]secret[/spoiler][size=12]taille[/size][hr]').html
    document = Nokogiri::HTML5.fragment(html)
    expect(document.css('[style]').pluck('style').join).not_to include('javascript', 'url(')
    expect(document.at_css('details summary').text).to eq('Lire')
    expect(document.at_css('hr')).to be_present
  end
end
