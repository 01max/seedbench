require 'rails_helper'

RSpec.describe Content::ReviewedAction do
  self.use_transactional_tests = false
  around { |example| with_preparation_storage { with_committed_cover_database { example.run } } }

  let(:release) { reviewed_content_release }

  def write_snapshot(operation)
    described_class.call(operation_id: operation.id, attempt_token: operation.attempt_token)
  end

  def host_for(operation)
    Covers::Host.call(operation_id: operation.id, attempt_token: operation.attempt_token)
  end

  before do
    choose_manual_cover(release)
    release.provider_assignments.find_by!(role: 'image_host').provider_connection.update!(endpoint: 'https://api.postimage.org', credentials: { 'api_key' => 'a' * 32 })
    stub_cover_hosting
    %w[bbcode nfo].each do |kind|
      proposal = Content::Propose.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: kind)
      Content::Accept.call(release_id: release.id, expected_revision: release.input_revision, proposal_id: proposal.id)
    end
    release.reload
  end

  it 'requires targeted URL acceptance and validates the final revision after fresh verification' do
    operation = cover_write_operation(release)
    host_for(operation)
    expect { write_snapshot(operation) }.to raise_error(Covers::Failure, /Acceptez/)
    proposal = Content::CoverPatch.call(release_id: release.id, expected_revision: release.input_revision)
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
    expect { write_snapshot(operation) }.to raise_error(Covers::Failure)
    final_operation = cover_write_operation(release.reload)
    expect { write_snapshot(final_operation) }.to raise_error(Covers::Failure)
    host_for(final_operation)
    snapshot = write_snapshot(final_operation)
    expect(snapshot.bbcode).to include('[img]https://i.postimg.cc/abc123/cover.png[/img]')
    expect(release.remote_snapshots.count).to eq(1)
  end

  it 'rejects a cover proposal after another selection and preserves newer human prose' do
    host_for(cover_write_operation(release))
    proposal = Content::CoverPatch.call(release_id: release.id, expected_revision: release.input_revision)
    before = release.content_revisions.where(kind: 'bbcode').order(:number).last.body
    choose_manual_cover(release, bytes: cover_bytes(color: 'red'))
    expect { Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.reload.input_revision) }.to raise_error(Content::Accept::StaleProposal)
    expect(release.content_revisions.where(kind: 'bbcode').order(:number).last.body).to eq(before)
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
  end
end
