module ReleasesHelper
  STATE_LABELS = { "pending" => "En attente", "running" => "En cours", "succeeded" => "Terminé", "failed" => "Échec",
    "unprepared" => "Non préparé", "prepared" => "Préparé", "stale" => "À revoir", "unlinked" => "Sans brouillon",
    "synced" => "Synchronisé", "conflicted" => "Conflit", "missing" => "Absent", "unpublished" => "Non publié",
    "submitting" => "Envoi en cours", "published" => "Publié", "outcome_unknown" => "Résultat incertain",
    "not_started" => "Non démarré", "checking" => "Vérification", "seeding" => "En partage", "unknown" => "Inconnu" }.freeze

  def queue_path(id, criteria:, **options)
    id ? release_path(id, **criteria, **options) : root_path(**criteria, **options)
  end

  def release_label(release)
    return "Publié" if release.publication_state == "published"
    return "Échec" if release.inspection_state == "failed"
    return "Analyse" if release.inspection_state == "running"
    return "À inspecter" if release.inspection_state == "pending"
    return "Préparé" if release.preparation_state == "prepared"

    "À relire"
  end

  def workflow_label(state)
    STATE_LABELS.fetch(state, state)
  end

  def content_body(snapshot, kind)
    snapshot.contents[kind]&.body.to_s
  end

  def fact_value(snapshot, field)
    snapshot.facts[field]&.value.to_s
  end

  def event_label(name)
    { "release.created" => "Release créée", "payload.staged" => "Fichier déposé", "release.revised" => "Texte enregistré",
      "operation.requested" => "Opération demandée", "operation.completed" => "Opération terminée",
      "operation.stale" => "Ancien résultat écarté" }.fetch(name, name.tr("._", " "))
  end
end
