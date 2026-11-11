module Publications
  class Gate
    def self.call(release:, before_send: false)
      new(release, before_send).call
    end

    def initialize(release, before_send)
      @release = release
      @before_send = before_send
      @inputs = Content::Inputs.new(release)
    end

    def call
      prerequisite_reasons + review_reasons + content_reasons + duplicate_reasons
    end

    private

    def prerequisite_reasons
      reasons = []
      reasons << 'publication_state' unless %w[unpublished failed].include?(@release.publication_state)
      reasons << 'inspection' unless @inputs.inspected?
      reasons << preparation_reason unless @inputs.prepared?
      reasons << 'cover_review' unless Covers::Policy.current?(release: @release, cover: @inputs.cover)
      reasons << 'hosted_cover' if @before_send && !@inputs.hosting
      reasons
    end

    def duplicate_reasons
      Duplicates::Assessment.new(@release).ready? ? [] : [ 'duplicates' ]
    end

    def preparation_reason
      @inputs.payload ? 'preparation' : 'payload'
    end

    def review_reasons
      checklist = Releases::Snapshot.call(release: @release).findings
      reasons = Releases::MarkCheck::KEYS.reject do |key|
        @release.manual_checks.where(key: key).order(:id).last&.checked_at_revision?(@release.input_revision)
      end
      reasons << 'mechanical_failure' if checklist.any? { |finding| finding.severity == 'failure' }
      reasons << 'acknowledgements' if checklist.any? { |finding| unacknowledged?(finding) }
      reasons
    end

    def unacknowledged?(finding)
      finding.severity == 'uncertainty' && !finding.finding_acknowledgements.max_by(&:id)&.acknowledged
    end

    def content_reasons
      states = Content::Status.call(release: @release).kinds
      states.filter_map do |kind, value|
        next if value[:state] == 'ready'
        next if kind == 'bbcode' && !@before_send && !@inputs.hosting

        kind
      end
    end
  end
end
