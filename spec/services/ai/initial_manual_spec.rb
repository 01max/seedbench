require 'rails_helper'

RSpec.describe Ai::Initial do
  self.use_transactional_tests = false
  around { |example| with_preparation_storage { with_committed_cover_database { example.run } } }

  def manual_release
    root = Rails.application.config.x.storage.fetch(:scratch)
    release = Dir.mktmpdir('manual-ebook-', root) do |directory|
      system('python3', Rails.root.join('script/ebooks/fixtures.py').to_s, directory, exception: true)
      upload = Rack::Test::UploadedFile.new(File.join(directory, 'book.epub'), 'application/epub+zip')
      Releases::Intake.call(uploads: [ upload ]).releases.sole
    end
    Workflows::Execute.call(operation_id: release.workflow_operations.sole.id)
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: {
      title: 'Synthetic book', author: 'Test author', language: 'fr', publisher: 'Synthetic publisher', publication_year: '2024',
      isbn_kind: 'not_applicable', presentation: 'Présentation rédigée et relue manuellement pour ce livre synthétique.' })
  end

  def assign_connections(release)
    configure_cover_host(release)
    %w[publishing ai].each do |role|
      credentials = { api_key: 'synthetic-manual-path-key' }
      options = role == 'ai' ? { model: 'synthetic-model' } : {}
      connection = Settings::CreateConnection.call(role: role, label: "Synthetic #{role}", identity_key: SecureRandom.uuid, credentials: credentials, options: options)
      Settings::AssignConnection.call(release_id: release.id, role: role, connection_id: connection.id, expected_revision: release.reload.input_revision)
    end
  end

  def optional_ai(release, enabled)
    release.reload.update!(automatic_ai: enabled)
    described_class.call(release: release)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(status: 503)
    release.ai_runs.each { |run| Workflows::Execute.call(operation_id: run.workflow_operation_id) }
  end

  def prepare_and_review(release)
    choose_manual_cover(release)
    Preparation::SuggestName.call(release: release.reload)
    operation = Preparation::Request.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Workflows::Execute.call(operation_id: operation.id)
    %w[edition_review text_review].each { |key| Releases::MarkCheck.call(release_id: release.id, key: key, checked: true, expected_revision: release.reload.input_revision) }
    %w[bbcode nfo].each do |kind|
      proposal = Content::Propose.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: kind)
      Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
    end
  end

  def validate_explicit_boundary(release)
    stub_cover_hosting
    first = cover_write_operation(release)
    Covers::Host.call(operation_id: first.id, attempt_token: first.attempt_token)
    proposal = Content::CoverPatch.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
    operation = cover_write_operation(release, kind: 'publish')
    Covers::Host.call(operation_id: operation.id, attempt_token: operation.attempt_token)
    stub_duplicate_search(body: '<rss><channel/></rss>')
    Duplicates::Refresh.call(operation_id: operation.id, attempt_token: operation.attempt_token)
    Content::ReviewedAction.call(operation_id: operation.id, attempt_token: operation.attempt_token)
  end

  [ false, true ].each do |enabled|
    it "completes the manual prerequisite checks with AI #{enabled ? 'unavailable' : 'disabled'} without publishing" do
      release = manual_release
      assign_connections(release)
      optional_ai(release, enabled)
      prepare_and_review(release)
      snapshot = validate_explicit_boundary(release)
      expect(snapshot.bbcode).to include('Présentation rédigée et relue manuellement')
      states = Releases::Checklist.call(release: release.reload).index_by(&:key)
      expect(states.values_at('inspection', 'preparation', 'cover', 'content', 'duplicates', 'edition_review', 'text_review').map(&:state)).to all(eq('done'))
      expect(states['ai'].required).to be(false)
      expect(WebMock).not_to have_requested(:post, %r{c411.org})
      expect(release.publication_state).to eq('unpublished')
    end
  end
end
