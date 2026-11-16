require 'rails_helper'

RSpec.describe 'Release archives' do
  it 'renders archive and restore disabled until the editor initializes' do
    sign_in_operator
    release = Releases::Create.call
    archive_action = 'button[data-editor-target="archiveAction"][disabled]'

    get release_path(release)
    expect(response.parsed_body.at_css(archive_action).text).to eq('Archiver')

    post release_archive_path(release)
    get release_path(release)
    expect(response.parsed_body.at_css(archive_action).text).to eq('Restaurer')
  end

  it 'archives a published record without changing its revision or workflows and only records the transition once' do
    sign_in_operator
    release = Releases::Create.call(title: 'Published book')
    release.update!(publication_state: 'published', seeding_state: 'succeeded')

    2.times { post release_archive_path(release) }
    expect(response).to redirect_to(root_path)
    expect(release.reload).to have_attributes(publication_state: 'published', seeding_state: 'succeeded', input_revision: 0)
    expect(release.release_events.where(name: 'release.archived').count).to eq(1)

    get root_path(state: 'published')
    expect(response.parsed_body.css('.queue-row')).to be_empty
    get root_path(state: 'archived', q: 'published book')
    expect(response.parsed_body.at_css('.queue-row').text).to include('Published book', 'Archivé')
  end
end
