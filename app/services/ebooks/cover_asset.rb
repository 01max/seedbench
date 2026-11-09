module Ebooks
  class CoverAsset
    class << self
      def call(release:, evidence_id:, sha256:)
        evidence = release.evidence_items.find(evidence_id)
        candidate = Array(evidence.data["covers"]).find { |cover| cover["sha256"] == sha256 }
        raise ActiveRecord::RecordNotFound unless candidate && sha256.match?(/\A[0-9a-f]{64}\z/)

        [ safe_path(sha256), candidate.fetch("media_type") ]
      end

      private

      def safe_path(sha256)
        root = Rails.application.config.x.storage.fetch(:state).realpath
        path = root.join("inspection-covers", sha256)
        raise ActiveRecord::RecordNotFound unless path.realpath.to_s.start_with?("#{root}/") && !path.symlink? && Digest::SHA256.file(path).hexdigest == sha256

        path
      rescue Errno::ENOENT
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end
