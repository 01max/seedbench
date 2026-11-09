require "rails_helper"

RSpec.describe "Batch upload" do
  after { FileUtils.rm_rf(Rails.application.config.x.storage.fetch(:payload).join("staging")) }

  it "requires authentication before accepting files" do
    post uploads_path, params: { files: [ ebook_upload ] }

    expect(response).to redirect_to(new_operator_session_path)
    expect(Release.count).to eq(0)
  end

  it "accepts a mixed batch locally and presents individual errors" do
    sign_in_operator
    post uploads_path, params: { files: [ ebook_upload, ebook_upload("Bad.zip") ] }
    follow_redirect!

    expect(response.body).to include("1 fichier ajouté", "Bad.zip", "Format non pris en charge")
    expect(Release.count).to eq(1)
    expect(PreparationRevision.count).to eq(0)
  end

  it "reports a missing selection" do
    sign_in_operator
    post uploads_path
    follow_redirect!

    expect(response.body).to include("Choisissez entre 1 et 50 fichiers")
  end

  it "accepts non-UTF-8 ebook bytes without changing their identity" do
    bytes = "\xD2".b
    sign_in_operator
    post uploads_path, params: { files: [ ebook_upload("Binary.epub", bytes: bytes) ] }

    expect(response).to have_http_status(:see_other)
    payload = Release.last.payload_revisions.sole
    expect(Rails.application.config.x.storage.fetch(:payload).join(payload.locator).binread).to eq(bytes)
    expect(payload.sha256).to eq(Digest::SHA256.hexdigest(bytes))
  end

  it "shows a grouped error without a success message when every file is rejected" do
    sign_in_operator
    post uploads_path, params: { files: [ ebook_upload("Unsupported.zip"), ebook_upload(bytes: "") ] }
    follow_redirect!

    document = response.parsed_body
    expect(document.css('.flash-message--error[role="alert"] li').size).to eq(2)
    expect(document.css(".flash-message--success")).to be_empty
    expect(Release.count).to eq(0)
  end
end
