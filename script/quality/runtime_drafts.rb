abort 'Use only the disposable runtime stack' unless ENV['SEEDBENCH_RUNTIME_VERIFICATION'] == '1'

module RuntimeDrafts
  class << self
    def prepare
      release = Releases::Create.call(title: 'Synthetic draft persistence')
      connection = release.provider_assignments.find_by!(role: 'publishing').provider_connection
      link = DraftLink.create!(release: release, provider_connection: connection, remote_id: 'synthetic-runtime-draft')
      base = Drafts::Content.local(release).merge('description' => 'Synthetic shared base')
      Drafts::Content.adopt(release, base)
      release.remote_snapshots.create!(provider_connection: connection, kind: 'draft', remote_id: link.remote_id,
        local_revision: release.reload.input_revision, base_content: base, remote_content: base, observed_at: Time.current)
      Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'Human local draft edit' })
      Drafts::Observe.call(link: link, content: base.merge('description' => 'Other client remote edit'), remote_revision: 'synthetic-remote-revision')
      write = uncertain_write(release.reload, connection, link)
      Rails.application.config.x.storage.fetch(:scratch).join('runtime-draft.json').write(JSON.generate(write_id: write.id,
        request_sha256: Digest::SHA256.hexdigest(JSON.generate(write.request))))
    end

    def verify
      saved = JSON.parse(Rails.application.config.x.storage.fetch(:scratch).join('runtime-draft.json').read)
      write = DraftWrite.find(saved.fetch('write_id'))
      release = write.release
      abort 'Draft request identity changed' unless Digest::SHA256.hexdigest(JSON.generate(write.request)) == saved.fetch('request_sha256')
      abort 'Unknown draft write was replayed' unless write.state == 'unknown' && write.workflow_operation.state == 'outcome_unknown'
      abort 'Draft conflict or identity disappeared' unless release.draft_state == 'conflicted' && release.draft_link.remote_id == 'synthetic-runtime-draft'
      abort 'Human draft content was lost' unless Drafts::Content.local(release)['description'] == 'Human local draft edit'
      abort 'Remote draft evidence was lost' unless release.remote_snapshots.order(:id).last.remote_content['description'] == 'Other client remote edit'
      puts 'Draft identity, three-way conflict, human text and uncertain write intent survived recreation without provider calls.'
    end

    private

    def uncertain_write(release, connection, link)
      operation = release.workflow_operations.create!(kind: 'draft_write', request_key: SecureRandom.uuid, input_revision: release.input_revision,
        effect: 'remote', state: 'outcome_unknown', phase: 'draft_sending', attempts: 1)
      operation.create_dispatch_intent!(release: release, state: 'dispatched', dispatched_at: Time.current)
      release.draft_writes.create!(workflow_operation: operation, provider_connection: connection, action: 'update', remote_id: link.remote_id,
        state: 'unknown', request: { 'content' => Drafts::Content.local(release), 'connection_version' => connection.credentials_version },
        body: Drafts::Content.local(release).except('nfo'))
    end
  end
end
