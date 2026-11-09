module ReleasesHelper
  def queue_path(id, criteria:, **options)
    id ? release_path(id, **criteria, **options) : root_path(**criteria, **options)
  end

  def release_label(release)
    return t("workbench.queue.labels.published") if release.publication_state == "published"
    return t("workbench.queue.labels.failed") if release.inspection_state == "failed"
    return t("workbench.queue.labels.running") if release.inspection_state == "running"
    return t("workbench.queue.labels.pending") if release.inspection_state == "pending"
    return t("workbench.queue.labels.prepared") if release.preparation_state == "prepared"

    t("workbench.queue.labels.review")
  end

  def workflow_label(state)
    t("workbench.states.#{state}", default: t("workbench.states.unknown"))
  end

  def operation_phase_label(phase)
    t("workbench.phases.#{phase}", default: t("workbench.phases.other"))
  end

  def content_body(snapshot, kind)
    snapshot.contents[kind]&.body.to_s
  end

  def event_label(name)
    t("workbench.events.#{name}", default: t("workbench.events.other", name: name))
  end
end
