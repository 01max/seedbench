module PreparationFixtures
  def with_preparation_storage
    storage = Rails.application.config.x.storage
    Dir.mktmpdir('preparation-', storage.fetch(:payload)) do |directory|
      roots = %i[payload state scratch].index_with { |kind| Pathname.new(directory).join(kind.to_s) }
      roots.each_value(&:mkpath)
      Rails.application.config.x.storage = roots.merge(deluge_payload: '/client library/books')
      yield
    ensure
      Rails.application.config.x.storage = storage
    end
  end

  def staged_preparation_release(format: 'epub', bytes: "Synthetic preparation bytes\n")
    release = Releases::Create.call(title: 'Synthetic book', author: 'Test Author')
    path = Rails.application.config.x.storage.fetch(:payload).join('staging', "#{SecureRandom.uuid}.#{format}")
    path.parent.mkpath
    path.binwrite(bytes)
    release.payload_revisions.create!(number: 1, locator: "staging/#{path.basename}", original_filename: "Original.#{format}",
      format: format, sha256: Digest::SHA256.file(path).hexdigest, size_bytes: path.size)
    release.evidence_items.create!(payload_revision: release.payload_revisions.sole, evidence_key: "inspection-#{release.id}", kind: 'inspection', source: 'Synthetic inspection', captured_at: Time.current, input_revision: 0, data: { error: nil, structure: {} })
    release.update!(inspection_state: 'succeeded')
    release
  end

  def preparation_operation(release, name: 'Synthetic.Book.Test.Author.FRENCH.[EPUB]-NOTAG')
    release.update!(proposed_name: name)
    operation = release.workflow_operations.create!(kind: 'preparation', request_key: SecureRandom.uuid, effect: 'filesystem',
      input_revision: release.input_revision, parameters: { payload_revision_id: release.payload_revisions.sole.id, release_name: name })
    operation.update!(state: 'running', attempt_token: SecureRandom.uuid, lease_expires_at: 5.minutes.from_now)
    operation.create_dispatch_intent!(release: release)
    operation
  end
end

RSpec.configure { |config| config.include PreparationFixtures }
