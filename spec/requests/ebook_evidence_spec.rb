require "rails_helper"

RSpec.describe "Ebook evidence" do
  let(:release) { build_release_graph }

  it "protects analysis, fact adoption, and cover access behind authentication" do
    get release_evidence_path(release)
    expect(response).to redirect_to(new_operator_session_path)
    post release_evidence_path(release), params: { inspection: { kind: "inspect", expected_revision: 0 } }
    expect(response).to redirect_to(new_operator_session_path)
    post release_fact_reviews_path(release), params: { review: { evidence_id: 1, candidate_index: 0, expected_revision: 0 } }
    expect(response).to redirect_to(new_operator_session_path)
    get release_cover_candidate_path(release, "a" * 64, evidence_id: 1)
    expect(response).to redirect_to(new_operator_session_path)
  end

  it "queues only a local inspection and renders evidence without replacing the editor" do
    sign_in_operator
    post release_evidence_path(release), params: { inspection: { kind: "inspect", expected_revision: 0 } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("evidence_release_#{release.id}", "Analyse demandée")
    expect(response.body).not_to include('id="release-editor"')
    expect(release.workflow_operations.sole).to have_attributes(kind: "inspection", effect: "local")
  end

  it "rejects stale, unsupported, and invalid lookup requests" do
    sign_in_operator
    %w[inspect ocr lookup publish].each do |kind|
      post release_evidence_path(release), params: { inspection: { kind: kind, expected_revision: kind == "inspect" ? 5 : 0, isbn: "invalid" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(release.workflow_operations).to be_empty
  end

  it "shows candidates and accepts only a candidate from the selected release" do
    evidence = release.evidence_items.create!(payload_revision: release.payload_revisions.sole, evidence_key: "candidate", kind: "inspection",
      source: "Synthetic", captured_at: Time.current, input_revision: 0, data: { candidates: [ { field: "title", value: "Review title", source: "synthetic" } ] })
    sign_in_operator
    post release_fact_reviews_path(release), params: { review: { evidence_id: evidence.id, candidate_index: 0, expected_revision: 0 } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-reviewed-values", "Review title")
    expect(release.reload.title).to eq("Review title")
  end
end
