require "rails_helper"

RSpec.describe "Ebook cover candidates" do
  let(:directory) { Pathname.new(Dir.mktmpdir("ebook-cover-")) }

  before do
    system("python3", Rails.root.join("script/ebooks/fixtures.py").to_s, directory.to_s, exception: true)
  end

  after do
    FileUtils.remove_entry(directory)
    FileUtils.rm_rf(Rails.application.config.x.storage.fetch(:payload).join("staging"))
  end

  it "serves the measured image only through its owning evidence" do
    upload = Rack::Test::UploadedFile.new(directory.join("book.epub"), "application/epub+zip")
    release = Releases::Intake.call(uploads: [ upload ]).releases.sole
    Workflows::Execute.call(operation_id: release.workflow_operations.sole.id)
    evidence = release.evidence_items.sole
    sha256 = evidence.data.fetch("covers").first.fetch("sha256")
    sign_in_operator
    get release_cover_candidate_path(release, sha256, evidence_id: evidence.id)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(Digest::SHA256.hexdigest(response.body)).to eq(sha256)
    get release_cover_candidate_path(release, "a" * 64, evidence_id: evidence.id)
    expect(response).to have_http_status(:not_found)
  end
end
