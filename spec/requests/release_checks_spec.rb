require "rails_helper"

RSpec.describe "Release checklist" do
  it "updates a reversible mark inside only the status frame" do
    release = Releases::Create.call(title: "Synthetic")
    sign_in_operator
    post release_checks_path(release), params: { mark: { key: "text_review", checked: "1", expected_revision: 0 } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("status_release_#{release.id}", 'data-check-state="done"')
    expect(response.body).not_to include('id="release-editor"')
    expect(release.manual_checks.sole.checked).to be(true)
  end

  it "rejects a forged automatic mark and protects unauthenticated writes" do
    release = Releases::Create.call
    post release_checks_path(release), params: { mark: { key: "inspection", checked: "1", expected_revision: 0 } }
    expect(response).to redirect_to(new_operator_session_path)
    sign_in_operator
    post release_checks_path(release), params: { mark: { key: "inspection", checked: "1", expected_revision: 0 } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(release.manual_checks.count).to eq(0)
    expect(release.reload.inspection_state).to eq("pending")
  end

  it "rejects stale form revisions with current controls available" do
    release = Releases::Create.call
    sign_in_operator
    post release_checks_path(release), params: { mark: { key: "text_review", checked: "1", expected_revision: 5 } }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Le livre a changé", "Texte relu")
  end

  it "acknowledges the exact current uncertainty revision" do
    release = build_release_graph
    finding = release.findings.sole
    sign_in_operator
    post release_checks_path(release), params: { mark: { finding_id: finding.id, number: finding.number, checked: "0", expected_revision: 0 } }

    expect(response).to have_http_status(:ok)
    expect(finding.finding_acknowledgements.order(:id).last.acknowledged).to be(false)
  end
end
