module Releases
  class Checklist
    Item = Data.define(:key, :label, :required, :owner, :state, :note, :checked, :finding)

    def self.call(release:, snapshot: Snapshot.call(release: release))
      new(release, snapshot).call
    end

    def initialize(release, snapshot)
      @release, @snapshot = release, snapshot
      @marks = release.manual_checks.where(id: release.manual_checks.select('MAX(id)').group(:key)).index_by(&:key)
    end

    def call
      core_steps + warnings + content_steps + optional_steps + outcomes
    end

    private

    def item(key, label = I18n.t("workbench.checklist.#{key}.label"), state:, note:, owner: :auto, required: true, checked: false, finding: nil)
      Item.new(key: key, label: label, state: state, note: note, owner: owner, required: required, checked: checked, finding: finding)
    end

    def core_steps
      [ inspection, manual('edition_review'), cover, manual('text_review'), preparation, duplicates ]
    end

    def manual(key)
      checked = @marks[key]&.checked || false
      item(key, state: checked ? 'done' : 'pending', checked: checked, owner: :operator, note: I18n.t('workbench.checklist.manual_note'))
    end

    def inspection
      failed = @snapshot.findings.any? { |finding| finding.severity == 'failure' }
      state = failed || @release.inspection_state == 'failed' ? 'blocked' : 'pending'
      state = 'done' if !failed && @release.inspection_state == 'succeeded'
      item('inspection', state: state, note: I18n.t("workbench.checklist.inspection.#{failed ? 'failed' : 'pending'}"))
    end

    def cover
      selected = @snapshot.covers.first
      hosting = Content::Inputs.new(@release).hosting
      hosted = hosting.present?
      item('cover', state: hosted ? 'done' : 'pending', owner: :mixed,
        note: I18n.t("workbench.checklist.cover.#{selected ? 'selected' : 'missing'}"))
    end

    def preparation
      prepared = @snapshot.preparation
      payload = @snapshot.payload
      done = Preparation::Current.call(release: @release, payload: payload, preparation: prepared)
      item('preparation', state: done ? 'done' : 'pending', note: I18n.t("workbench.checklist.preparation.#{done ? 'done' : 'pending'}"))
    end

    def duplicates
      assessment = Duplicates::Assessment.new(@release)
      state = assessment.blocked? ? 'blocked' : 'pending'
      state = 'done' if assessment.ready?
      item('duplicates', state: state, owner: :c411, note: I18n.t("duplicates.gate.#{state}"))
    end

    def content_steps
      states = Content::Status.call(release: @release).kinds.values.pluck(:state)
      complete = states.all?('ready')
      state = complete ? 'done' : 'pending'
      note = I18n.t("content.checklist.#{complete ? 'ready' : 'review'}")
      [ item('content', state: state, note: note) ]
    end

    def optional_steps
      draft = @snapshot.snapshots['draft']
      ai = @release.ai_runs.order(:id).last
      [ item('draft', required: false, owner: :c411, state: draft && !draft.remote_deleted ? 'done' : 'optional', note: I18n.t('workbench.checklist.draft.note')),
        item('ai', required: false, state: ai&.status == 'succeeded' ? 'done' : 'optional', note: I18n.t('workbench.checklist.ai.note')) ]
    end

    def outcomes
      [ item('publication', owner: :c411, state: @release.publication_state == 'published' ? 'done' : 'pending', note: I18n.t('workbench.checklist.publication.note')),
        item('seeding', state: @release.seeding_state == 'succeeded' ? 'done' : 'pending', note: I18n.t('workbench.checklist.seeding.note')) ]
    end

    def warnings
      @snapshot.findings.select { |finding| finding.severity == 'uncertainty' }.map do |finding|
        acknowledged = finding.finding_acknowledgements.max_by(&:id)&.acknowledged || false
        item("finding_#{finding.id}", finding.message, state: acknowledged ? 'done' : 'pending', owner: :operator,
          checked: acknowledged, finding: finding, note: I18n.t('workbench.checklist.warning_note', number: finding.number))
      end
    end
  end
end
