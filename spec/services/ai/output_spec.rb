require 'rails_helper'

RSpec.describe Ai::Output do
  let(:pack) { Ai::EvidencePack.call(release: reviewed_content_release) }

  def validate(output, purpose: 'assessment')
    described_class.call(purpose: purpose, output: output, pack: pack)
  end

  it 'accepts only source-supported candidate facts and advisory findings' do
    output = ai_output(pack)
    expect(validate(output)).to eq(output)
    output['candidates'].first['value'] = 'Invented title'
    expect { validate(output) }.to raise_error(Ai::Failure)
  end

  it 'rejects unknown fields, unsupported citation IDs and malformed types at any depth' do
    output = ai_output(pack)
    [ output.merge('publish' => true), output.merge('candidates' => 'Wrong type'),
      output.merge('findings' => [ { 'summary' => 'A claim', 'evidence_ids' => [ 'foreign' ] } ]) ].each do |value|
      expect { validate(value) }.to raise_error(Ai::Failure)
    end
  end

  it 'rejects generated technical fields, markup and oversized prose while accepting explicit insufficient evidence' do
    output = ai_output(pack, purpose: 'prose')
    [ 'ISBN 9780306406157', '[b]Du texte[/b]', 'https://evil.invalid', 'a' * 4001 ].each do |value|
      expect { validate(output.merge('presentation' => value), purpose: 'prose') }.to raise_error(Ai::Failure)
    end
    expect(validate(output.merge('presentation' => nil, 'evidence_ids' => []), purpose: 'prose')['presentation']).to be_nil
  end
end
