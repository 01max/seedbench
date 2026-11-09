require "rails_helper"

RSpec.describe "Reviewing the displayed edit revision", type: :system do
  let(:release) do
    record = Releases::Create.call(title: "Synthetic")
    Releases::Save.call(release_id: record.id, expected_revision: 0, changes: { presentation: "Displayed prose" })
    record
  end

  before do
    sign_in_browser
    open_editor(release)
  end

  it "requires loading unseen prose before marking its newer revision as reviewed" do
    Releases::Save.call(release_id: release.id, expected_revision: 1, changes: { presentation: "Unseen replacement prose" })
    find('button[aria-label="Actualiser les contrôles"]').click
    find('[data-check-key="text_review"] input[name="mark[expected_revision]"][value="2"]', visible: :all)
    within('[data-check-key="text_review"]') { check "Texte relu" }
    expect(page).to have_text("Le livre a changé")
    expect(release.manual_checks.count).to eq(0)
    click_link "Recharger le texte enregistré"
    expect(page).to have_field("Présentation", with: "Unseen replacement prose")
    within('[data-check-key="text_review"]') { check "Texte relu" }
    expect(page).to have_css('[data-check-key="text_review"][data-check-state="done"]')
    expect(release.manual_checks.sole.input_revision).to eq(2)
  end

  it "saves pending displayed edits before binding the review to their new revision" do
    fill_in "Présentation", with: "Currently displayed edit"
    within('[data-check-key="text_review"]') { check "Texte relu" }
    expect(page).to have_css('[data-check-key="text_review"][data-check-state="done"]')

    expect(release.content_revisions.where(kind: "presentation").order(:number).last.body).to eq("Currently displayed edit")
    expect(release.manual_checks.sole.input_revision).to eq(release.reload.input_revision)
    expect(release.input_revision).to eq(2)
  end
end
