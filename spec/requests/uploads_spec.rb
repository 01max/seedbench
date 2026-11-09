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
end
