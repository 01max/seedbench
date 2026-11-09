require 'rails_helper'

RSpec.describe Content::Bbcode do
  it 'detects invalid nesting and unsupported tags' do
    expect(described_class.call(source: '[b][i]text[/b][/i]').errors).to include('invalid_nesting')
    expect(described_class.call(source: '[script]unsafe[/script]').errors).to include('unsupported_tag')
    expect(described_class.call(source: '[unfinished').errors).to include('unsupported_tag')
  end

  it 'keeps code contents inert and handles list items' do
    result = described_class.call(source: '[code][img]unsafe[/img][/code][list][*]one[*]two[/list]')
    expect(result.errors).to be_empty
    expect(result.nodes.first.children).to eq([ '[img]unsafe[/img]' ])
    expect(result.nodes.last.children.size).to eq(2)
  end

  it 'bounds pathological markup' do
    expect(described_class.call(source: '[b]' * 40).errors).to eq([ 'markup_limit' ])
  end
end
