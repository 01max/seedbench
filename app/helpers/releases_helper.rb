module ReleasesHelper
  def queue_path(id, criteria:, **options)
    id ? release_path(id, **criteria, **options) : root_path(**criteria, **options)
  end

  def release_label(release)
    return t('workbench.c411.badge') if release.c411_imported?
    return t('workbench.queue.labels.archived') if release.archived_at?
    return t('duplicates.confirmed_tag') if Duplicates::Assessment.new(release).confirmed?
    return t('workbench.queue.labels.published') if release.publication_state == 'published'
    return t("workbench.queue.labels.#{release.inspection_state}") if %w[failed running pending].include?(release.inspection_state)
    return t('workbench.queue.labels.prepared') if release.preparation_state == 'prepared'

    t('workbench.queue.labels.review')
  end

  def workflow_label(state)
    t("workbench.states.#{state}", default: t('workbench.states.unknown'))
  end

  def operation_phase_label(phase)
    t("workbench.phases.#{phase}", default: t('workbench.phases.other'))
  end

  def content_body(snapshot, kind)
    snapshot.contents[kind]&.body.to_s
  end

  def event_label(name)
    t("workbench.events.#{name}", default: t('workbench.events.other', name: name))
  end
end
