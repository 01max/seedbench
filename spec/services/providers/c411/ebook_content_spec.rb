require 'rails_helper'

RSpec.describe Providers::C411::EbookContent do
  let(:values) { described_class::FIELDS.index_with { |field| "Value #{field}" } }

  it 'preserves the operator skeleton and its exact label order' do
    body = described_class.assemble(values: values)
    expect(body).to start_with("[center][img]Value cover[/img][/center]\n\n[center][b]Value title[/b][/center]\n\n\n\n")
    expect(described_class.fields(body: body)).to eq(values)
    expect(body).to end_with("Notes supplémentaire : Value notes\n")
  end

  it 'does not interpret bracketed facts as markup' do
    expect(described_class.escape('[img]unsafe[/img]')).to eq('&#91;img&#93;unsafe&#91;/img&#93;')
    expect(described_class.safe_url?('javascript:alert(1)')).to be(false)
    expect(described_class.safe_url?('https://user:secret@example.invalid/image')).to be(false)
    expect(described_class.safe_url?('https://images.invalid/cover.png')).to be(true)
  end

  it 'keeps portrait orientation and valid dimensions without imposing a size minimum' do
    dimensions = Struct.new(:width, :height)

    expect(described_class.portrait_cover?(dimensions.new(1, 2))).to be(true)
    expect(described_class.portrait_cover?(dimensions.new(0, 900))).to be(false)
    expect(described_class.portrait_cover?(dimensions.new(900, 600))).to be(false)
  end
end
