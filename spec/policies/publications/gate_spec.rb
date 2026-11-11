require 'rails_helper'

RSpec.describe Publications::Gate do
  it 'lists missing publication requirements on the server' do
    release = Releases::Create.call

    expect(described_class.call(release: release, before_send: true)).to contain_exactly(
      'inspection', 'payload', 'cover_review', 'hosted_cover', 'edition_review',
      'text_review', 'bbcode', 'nfo', 'duplicates'
    )
  end

  it 'rejects another publication while an earlier submission is unresolved' do
    release = Releases::Create.call
    release.update!(publication_state: 'outcome_unknown')

    expect(described_class.call(release: release)).to include('publication_state')
  end
end
