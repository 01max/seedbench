require "rails_helper"

RSpec.describe "Release provider assignments" do
  before { sign_in_operator }

  it "renders explicit unconfigured roles and assigns one without remote calls" do
    release = Releases::Create.call(title: "Synthetic release")
    connection = create_connection
    get release_connections_path(release)
    expect(response.body).to include("Non configuré pour ce livre", "Synthetic release")
    patch release_connections_path(release), params: { assignment: { role: "publishing", connection_id: connection.id, expected_revision: 0 } }
    follow_redirect!

    expect(response.body).to include("Synthetic C411", "synthetic-account")
    expect(response.body).not_to include("synthetic-private-credential")
  end

  it "keeps an existing identity on conflicting reassignment" do
    release = Releases::Create.call
    first = create_connection
    Settings::AssignConnection.call(release_id: release.id, role: "publishing", connection_id: first.id, expected_revision: 0)
    other = create_connection(identity: "other-account")
    patch release_connections_path(release), params: { assignment: { role: "publishing", connection_id: other.id, expected_revision: 1 } }
    follow_redirect!

    expect(response.body).to include("possède déjà une identité")
    expect(release.provider_assignments.find_by!(role: "publishing").provider_connection_id).to eq(first.id)
  end
end
