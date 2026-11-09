require 'rails_helper'

RSpec.describe ContentProposal do
  let(:release) { reviewed_content_release }
  let(:proposal) { Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'bbcode') }

  it 'retains immutable proposal bodies and dependency provenance' do
    record = proposal
    expect { record.bodies = {} }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(record.reload.dependencies['bbcode']).to include('payload_revision_id' => release.payload_revisions.sole.id)
  end

  %w[UPDATE DELETE REPLACE].each do |action|
    it "blocks direct #{action} of stored proposal history" do
      record = proposal
      sql = case action
      when 'UPDATE' then "UPDATE content_proposals SET kind = 'cover' WHERE id = #{record.id}"
      when 'DELETE' then "DELETE FROM content_proposals WHERE id = #{record.id}"
      else "INSERT OR REPLACE INTO content_proposals SELECT * FROM content_proposals WHERE id = #{record.id}"
      end
      expect { ApplicationRecord.connection.execute(sql) }.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    end
  end
end
