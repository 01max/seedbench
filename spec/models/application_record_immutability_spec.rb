require "rails_helper"

RSpec.describe ApplicationRecord do
  let(:records) do
    release = build_release_graph
    start_synthetic_operation(release)
    rows = Release.reflect_on_all_associations(:has_many).filter_map { |association| release.public_send(association.name).first }
    rows << release.provider_assignments.find_by!(role: "publishing").provider_connection
    rows.index_by { |record| record.class.table_name }
  end

  before { install_workflow_definition }

  def replace_record(record, changes)
    attributes = record.attributes.merge(changes.stringify_keys)
    connection = ApplicationRecord.connection
    columns = attributes.keys.map { |name| connection.quote_column_name(name) }
    values = attributes.map { |name, value| connection.quote(record.class.type_for_attribute(name).serialize(value)) }
    connection.execute("INSERT OR REPLACE INTO #{connection.quote_table_name(record.class.table_name)} (#{columns.join(', ')}) VALUES (#{values.join(', ')})")
  end

  {
    "payload_revisions" => { original_filename: "rewritten.epub" },
    "provider_connections" => { identity_key: "rewritten-account" },
    "preparation_revisions" => { release_name: "Rewritten release" },
    "evidence_items" => { source: "Rewritten evidence source" },
    "reviewed_facts" => { value: "Rewritten fact" },
    "fact_evidence_links" => { updated_at: 1.hour.from_now },
    "findings" => { message: "Rewritten finding" },
    "finding_acknowledgements" => { note: "Rewritten acknowledgement" },
    "cover_revisions" => { source_locator: "covers/rewritten.png" },
    "cover_hostings" => { direct_url: "https://images.invalid/rewritten.png" },
    "content_revisions" => { body: "Overwritten human text" },
    "duplicate_checks" => { query: { rewritten: true } },
    "duplicate_decisions" => { reason: "Rewritten decision reason" },
    "remote_snapshots" => { remote_id: "rewritten-draft" },
    "release_events" => { name: "history.rewritten" },
    "workflow_operations" => { parameters: { rewritten: true } }
  }.each do |table, changes|
    it "rejects replacement of the existing #{table} primary key" do
      record = records.fetch(table)
      original = record.attributes

      expect { replace_record(record, changes) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(record.reload.attributes).to eq(original)
    end
  end

  %w[release_events content_revisions].each do |table|
    it "rejects replacement through the #{table} natural key with a different ID" do
      record = records.fetch(table)
      original = record.attributes

      expect { replace_record(record, id: record.id + 1000) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(record.reload.attributes).to eq(original)
    end
  end

  it "keeps mutable locators, connection labels and operation progress updateable" do
    payload = records.fetch("payload_revisions")
    connection = records.fetch("provider_connections")
    operation = records.fetch("workflow_operations")
    payload.update!(locator: "prepared/fixture.epub")
    connection.update!(label: "Updated label")
    operation.update!(phase: "computing")

    expect(payload.reload.locator).to eq("prepared/fixture.epub")
    expect(connection.reload.label).to eq("Updated label")
    expect(operation.reload.phase).to eq("computing")
  end

  it "allows a new content revision while preserving the old human text" do
    original = records.fetch("content_revisions")
    revised = ContentRevision.create!(original.attributes.except("id", "created_at", "updated_at").merge("number" => 2, "body" => "New revision"))

    expect(revised.number).to eq(2)
    expect(original.reload.body).to eq("Human text")
  end
end
