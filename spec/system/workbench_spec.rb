require "rails_helper"

RSpec.describe "Release workspace", type: :system do
  it "opens local content, source evidence and preview on demand" do
    release = build_release_graph
    release.content_revisions.create!(kind: "presentation", number: 1, body: "Preserved presentation", origin: "human", input_revision: 0)
    sign_in_browser
    visit release_path(release)
    click_button "BBCode", exact: true
    expect(page).to have_field("BBCode complet", with: "Human text")
    click_button "Sources", exact: true
    expect(page).to have_text("Synthetic uncertainty")
    click_button "Aperçu", exact: true
    expect(page).to have_css(".local-preview", text: "Preserved presentation")
  end
end
