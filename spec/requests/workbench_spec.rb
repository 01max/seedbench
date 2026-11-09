require 'rails_helper'

RSpec.describe 'Release workbench' do
  it 'requires authentication for a stored release' do
    release = Releases::Create.call(title: 'Private title')
    get release_path(release)

    expect(response).to redirect_to(new_operator_session_path)
    expect(response.body).not_to include('Private title')
  end

  it 'renders the actual queue, full content, findings and history safely' do
    release = build_release_graph
    release.content_revisions.create!(kind: 'presentation', number: 1, body: "<script>alert('unsafe')</script>", origin: 'human', input_revision: 0)
    sign_in_operator
    get release_path(release)

    expect(response.body).to include('Synthetic book', 'Human text', 'Synthetic uncertainty', 'synthetic-draft', 'fixture.epub')
    expect(response.body).to include('&lt;script&gt;')
    expect(response.body).not_to include("<script>alert('unsafe')")
  end

  it 'searches the actual queue beyond the sample size' do
    65.times { |index| Releases::Create.call(title: "Synthetic #{index}", author: "Author #{index}") }
    sign_in_operator
    get root_path, params: { q: 'Author 64' }

    expect(response.body).to include('Synthetic 64', '1 release')
    expect(response.body).not_to include('Synthetic 63')
  end
end
