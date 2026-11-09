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
end
