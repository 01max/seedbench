require 'rails_helper'

RSpec.describe 'Local content preview' do
  let(:release) { Releases::Create.call(title: 'Synthetic book') }

  it 'requires authentication' do
    post release_content_preview_path(release), params: { preview: { bbcode: '[b]Test[/b]' } }
    expect(response).to redirect_to(new_operator_session_path)
  end

  it 'renders submitted unsaved BBCode without writing local or remote content' do
    sign_in_operator
    post release_content_preview_path(release), params: { preview: { bbcode: '[b]Unsaved[/b]<script>bad()</script>' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['html']).to include('<strong>Unsaved</strong>', '&lt;script&gt;')
    expect(release.content_revisions).to be_empty
    expect(WorkflowOperation.count).to eq(0)
  end

  it 'previews a selected verified cover below the target dimensions' do
    record = reviewed_content_release
    hosting = add_hosted_content_cover(record, width: 300, height: 450)
    sign_in_operator

    post release_content_preview_path(record), params: { preview: { bbcode: "[img]#{hosting.direct_url}[/img]" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5.fragment(response.parsed_body['html']).at_css('img')['src']).to eq(hosting.direct_url)
  end
end
