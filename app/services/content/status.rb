module Content
  class Status
    State = Data.define(:kinds, :issues)
    SOURCE_ERRORS = %w[inspection_required french_required invalid_isbn].freeze

    def self.call(release:)
      new(release).call
    end

    def initialize(release)
      @release = release
      @draft = Generate.call(release: release)
      @contents = Releases::Snapshot.call(release: release).contents
    end

    def call
      issues = Validation.call(bbcode: @contents['bbcode']&.body.to_s, nfo: @contents['nfo']&.body.to_s,
        expected: @draft.expected, cover_url: @draft.expected['cover'].presence)
      issues += @draft.issues.select { |issue| SOURCE_ERRORS.include?(issue[:code]) }
      kinds = %w[bbcode nfo].index_with { |kind| state(kind, issues) }
      State.new(kinds: kinds, issues: issues)
    end

    private

    def state(kind, issues)
      current = @contents[kind]
      return { state: 'missing', issues: [], revision: nil } if current&.body.blank?

      own_issues = issues.select { |issue| relevant?(issue[:code], kind) }
      stale = current.dependencies['fingerprint'] != @draft.dependencies.dig(kind, 'fingerprint') || current.dependencies['policy_version'] != Providers::C411::EbookContent::VERSION
      { state: stale ? 'stale' : (own_issues.any? ? 'invalid' : 'ready'), issues: own_issues, revision: current }
    end

    def relevant?(code, kind)
      return true if SOURCE_ERRORS.include?(code)

      code.start_with?('nfo_') == (kind == 'nfo')
    end
  end
end
