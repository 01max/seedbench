require 'tmpdir'

abort 'Use only the disposable runtime stack' unless ENV['SEEDBENCH_RUNTIME_VERIFICATION'] == '1'

module RuntimeReviews
  class << self
    def prepare
      release = Releases::Create.call(title: 'Synthetic cover and duplicate review', author: 'Synthetic author')
      release.payload_revisions.create!(number: 1, original_filename: 'review.epub', format: 'epub', size_bytes: 42,
        sha256: 'a' * 64, locator: 'synthetic-review.epub')
      select_cover(release)
      check = search_evidence(release.reload)
      decide(release, check, 'confirmed', '')
      decide(release.reload, release.duplicate_checks.order(:id).last, 'false_positive', 'Different edition and format after manual comparison of the synthetic evidence.')
      Rails.application.config.x.storage.fetch(:scratch).join('runtime-review-id').write(release.id.to_s)
    end

    def verify
      release = Release.find(Rails.application.config.x.storage.fetch(:scratch).join('runtime-review-id').read.to_i)
      cover = release.cover_revisions.sole
      bytes = Covers::Asset.read(locator: cover.source_locator, sha256: cover.edition_evidence.fetch('sha256'))
      abort 'Cover selection or native dimensions changed' unless Covers::Image.call(bytes: bytes).slice('width', 'height') == { 'width' => 300, 'height' => 450 }
      abort 'A local cover selection caused hosting' if release.cover_hostings.exists? || release.cover_uploads.exists?
      abort 'Cover lost edition review provenance' unless Covers::Policy.current?(release: release, cover: cover)
      abort 'Duplicate review history changed' unless release.duplicate_decisions.order(:id).pluck(:decision) == %w[confirmed false_positive]
      abort 'Reasoned duplicate override lost relevance' unless Duplicates::Assessment.new(release).ready?
      puts 'Local cover bytes, edition provenance and append-only duplicate overrides survived recreation without external writes.'
    end

    private

    def select_cover(release)
      scratch = Rails.application.config.x.storage.fetch(:scratch)
      Dir.mktmpdir('runtime-review-', scratch) do |directory|
        path = File.join(directory, 'cover.png')
        system('python3', '-c', "from PIL import Image;import sys;Image.new('RGB',(300,450),'navy').save(sys.argv[1])", path, exception: true)
        File.open(path, 'rb') do |file|
          upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: 'cover.png', type: 'image/png')
          Covers::Select.call(release_id: release.id, expected_revision: release.input_revision, kind: 'manual', attributes: { image: upload },
            review: { edition_match: true, quality_reviewed: true })
        end
      end
    end

    def search_evidence(release)
      connection = release.provider_assignments.find_by!(role: 'publishing').provider_connection
      inputs = Duplicates::Inputs.call(release: release)
      release.duplicate_checks.create!(input_revision: release.input_revision, searched_at: Time.current,
        query: { status: 'complete', inputs: inputs, fingerprint: Duplicates::Inputs.fingerprint(inputs), connection_id: connection.id,
          connection_version: connection.credentials_version, search_id: SecureRandom.uuid },
        candidates: [ { key: 'synthetic-runtime-match', title: 'Synthetic other edition', format: [ 'PDF' ] } ])
    end

    def decide(release, check, decision, reason)
      Duplicates::Review.call(release_id: release.id, expected_revision: release.input_revision, check_id: check.id,
        candidate_key: 'synthetic-runtime-match', decision: decision, reason: reason)
    end
  end
end
