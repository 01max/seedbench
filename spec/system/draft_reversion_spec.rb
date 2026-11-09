require "rails_helper"

RSpec.describe "Reverted editor drafts", type: :system do
  let(:original) { "Original saved prose" }
  let(:release) do
    record = Releases::Create.call(title: "Synthetic")
    Releases::Save.call(release_id: record.id, expected_revision: 0, changes: { presentation: original })
    record
  end

  before do
    sign_in_browser
    open_editor(release)
  end

  it "discards an undone draft instead of restoring and autosaving it after reload" do
    delay_autosave_timer
    fill_in "Présentation", with: "Discarded replacement"
    fill_in "Présentation", with: original
    expect(page).to have_css("#save-status", text: "Enregistré")
    page.refresh
    find('#workbench[data-editor-ready="true"]')

    expect(page).to have_field("Présentation", with: original)
    expect(page.evaluate_script("sessionStorage.getItem('seedbench.release-draft.#{release.id}')")).to be_nil
    expect(release.content_revisions.where(kind: "presentation").count).to eq(1)
  end

  it "retains and saves an undo made while the replacement save is in flight" do
    hold_first_save_response
    fill_in "Présentation", with: "Replacement in flight"
    click_button "Enregistrer", exact: true
    find('#workbench[data-save-held="true"]')
    fill_in "Présentation", with: original
    draft = page.evaluate_script("JSON.parse(sessionStorage.getItem('seedbench.release-draft.#{release.id}'))")
    expect(draft.fetch("values").fetch("presentation")).to eq(original)
    page.execute_script("window.releaseSavedResponse()")
    expect(page).to have_css("#save-status", text: "Enregistré")

    expect(release.content_revisions.where(kind: "presentation").order(:number).last.body).to eq(original)
    expect(release.content_revisions.where(kind: "presentation").count).to eq(3)
  end
end
