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
end
