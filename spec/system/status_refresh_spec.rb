require "rails_helper"

RSpec.describe "Local status refresh", type: :system do
  let(:release) { Releases::Create.call(title: "Synthetic book") }
  let!(:operation) { release.workflow_operations.create!(kind: "synthetic", request_key: "status-proof", effect: "local", input_revision: 0) }

  before do
    sign_in_browser
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
  end

  def reject_browser_saves
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = (url, options = {}) => options.method === "PATCH"
        ? Promise.resolve(new Response(JSON.stringify({ message: "Échec synthétique" }), { status: 503, headers: { "Content-Type": "application/json" } }))
        : original(url, options)
    JS
  end

  it "updates completed operation state while keeping dirty editor nodes and text" do
    reject_browser_saves
    fill_in "Présentation", with: "Unsaved human text"
    page.execute_script("document.querySelector('#edit_presentation').dataset.retained = 'yes'")
    operation.update!(state: "failed", error_code: "synthetic_failure")
    Releases::RecordEvent.call(release_id: release.id, name: "operation.failed")
    expect(page).to have_css('[data-active-operations="false"]', wait: 5)
    expect(page).to have_css(".operation-state", text: "Échec")
    expect(page).to have_field("Présentation", with: "Unsaved human text")
    expect(page).to have_css('#edit_presentation[data-retained="yes"]')
    expect(page).to have_css(".refresh-state", text: "État local à jour")
  end

  it "bounds automatic reads and lets the operator request a new bounded refresh" do
    page.execute_script("document.querySelector('.release-checklist').dataset.statusPollLimitValue = '1'")
    expect(page).to have_css(".refresh-state", text: "Actualisation en pause", wait: 5)
    expect(page).to have_css('.release-checklist[data-status-poll-count="1"]')
    expect(page).not_to have_css('.release-checklist[data-status-poll-count="2"]', wait: 2)
    operation.update!(state: "failed")
    find('button[aria-label="Actualiser les contrôles"]').click
    expect(page).to have_css('[data-active-operations="false"]')
    expect(page).to have_css(".refresh-state", text: "État local à jour")
  end

  it "saves the displayed revision before rejecting an unavailable explicit action" do
    fill_in "Présentation", with: "Reviewed before action"
    page.execute_script("document.querySelector('button[formaction*=prepare]').disabled = false")
    click_button "Préparer", exact: true

    expect(page).to have_text("Cette action n’est pas disponible")
    expect(release.content_revisions.where(kind: "presentation").last.body).to eq("Reviewed before action")
    expect(release.preparation_revisions.count).to eq(0)
  end
end
