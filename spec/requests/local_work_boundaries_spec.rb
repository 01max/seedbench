require "rails_helper"

RSpec.describe "Local work boundaries" do
  after { FileUtils.rm_rf(Rails.application.config.x.storage.fetch(:payload).join("staging")) }

  def configure_all_defaults
    ids = Providers::Catalog::ROLES.keys.index_with { |role| create_connection(role).id }
    Settings::SetDefaults.call(automatic_ai: true, connection_ids: ids, expected_revision: 0)
  end

  it "performs no provider calls or preparation through upload, save, search, status and manual review" do
    configure_all_defaults
    allow(Providers::Http).to receive(:call).and_call_original
    sign_in_operator
    post uploads_path, params: { files: [ ebook_upload ] }
    release = Release.sole
    patch release_path(release), params: { edit: { expected_revision: 0, presentation: "Local prose", bbcode: "Local BBCode" } }, as: :json
    get root_path, params: { q: "Synthetic", state: "review" }
    get release_status_path(release)
    post release_checks_path(release), params: { mark: { key: "text_review", checked: "1", expected_revision: 1 } }

    expect(response).to have_http_status(:ok)
    expect(Providers::Http).not_to have_received(:call)
    expect([ PreparationRevision.count, CoverHosting.count, RemoteSnapshot.count, AiRun.count ]).to eq([ 0, 0, 0, 0 ])
  end

  it "rejects older autosave content after an immediate newer Save" do
    release = Releases::Create.call(title: "Current")
    sign_in_operator
    patch release_path(release), params: { edit: { expected_revision: 0, bbcode: "New BBCode", nfo: "New NFO" } }, as: :json
    patch release_path(release), params: { edit: { expected_revision: 0, bbcode: "Old BBCode", nfo: "Old NFO" } }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(Releases::EditorValues.call(release: release.reload)).to include("bbcode" => "New BBCode", "nfo" => "New NFO")
    expect(release.release_events.where(name: "release.revised").count).to eq(1)
  end

  it "requires valid CSRF for upload, edits, manual marks and reviewed actions" do
    release = Releases::Create.call(title: "Protected")
    sign_in_operator
    begin
      ActionController::Base.allow_forgery_protection = true
      rejected_requests(release)
      expect(release.reload.input_revision).to eq(0)
      expect(release.manual_checks.count).to eq(0)
      expect(Release.count).to eq(1)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  def rejected_requests(release)
    post uploads_path, params: { authenticity_token: "forged", files: [ ebook_upload ] }
    expect(response).to have_http_status(:unprocessable_content)
    patch release_path(release), params: { authenticity_token: "forged", edit: { expected_revision: 0, title: "Forged" } }
    expect(response).to have_http_status(:unprocessable_content)
    post release_checks_path(release), params: { authenticity_token: "forged", mark: { expected_revision: 0, key: "text_review", checked: "1" } }
    expect(response).to have_http_status(:unprocessable_content)
    patch action_release_path(release, kind: "publish"), params: { authenticity_token: "forged", edit: { expected_revision: 0, title: "Forged" } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
