module Releases
  class Checklist
    Item = Data.define(:key, :label, :required, :owner, :state, :note, :checked, :finding)

    def self.call(release:, snapshot: Snapshot.call(release: release))
      new(release, snapshot).call
    end

    def initialize(release, snapshot)
      @release, @snapshot = release, snapshot
      @marks = release.manual_checks.where(id: release.manual_checks.select("MAX(id)").group(:key)).index_by(&:key)
    end

    def call
      core_steps + content_steps + optional_steps + outcomes + warnings
    end

    private

    def item(key, label, state:, note:, owner: "Auto", required: true, checked: false, finding: nil)
      Item.new(key: key, label: label, state: state, note: note, owner: owner, required: required, checked: checked, finding: finding)
    end

    def core_steps
      [ inspection, manual("edition_review"), cover, manual("text_review"), preparation, duplicates ]
    end

    def manual(key)
      checked = @marks[key]&.checked || false
      item(key, MarkCheck::LABELS.fetch(key), state: checked ? "done" : "pending", checked: checked, owner: "Vous", note: "Marque de relecture réversible")
    end

    def inspection
      failed = @snapshot.findings.any? { |finding| finding.severity == "failure" }
      state = failed || @release.inspection_state == "failed" ? "blocked" : "pending"
      state = "done" if !failed && @release.inspection_state == "succeeded"
      item("inspection", "Inspection", state: state, note: failed ? "Échec vérifiable à résoudre" : "Structure et octets du fichier")
    end

    def cover
      selected = @snapshot.covers.first
      hosted = selected && selected.cover_hostings.exists?
      item("cover", "Couverture", state: hosted ? "done" : "pending", owner: "Revue + auto",
        note: selected ? "Choisie · hébergement à vérifier à l’envoi" : "Choisir une couverture correspondant à l’édition")
    end

    def preparation
      prepared = @snapshot.preparation
      payload = @snapshot.payload
      done = @release.preparation_state == "prepared" && preparation_matches_payload?(prepared, payload)
      item("preparation", "Préparation", state: done ? "done" : "pending", note: done ? "Identité du fichier et torrent conservés" : "Fichier et torrent à vérifier")
    end

    def preparation_matches_payload?(prepared, payload)
      return false unless prepared && payload

      prepared.payload_revision_id == payload.id && prepared.payload_sha256 == payload.sha256 && prepared.payload_size_bytes == payload.size_bytes
    end

    def duplicates
      check = @release.duplicate_checks.where(input_revision: @release.input_revision).order(:id).last
      blocked = check && check.duplicate_decisions.exists?(decision: %w[confirmed likely])
      state = blocked ? "blocked" : "pending"
      state = "done" if check && check.candidates.empty? && !blocked
      item("duplicates", "Doublons", state: state, owner: "C411", note: blocked ? "Correspondance à examiner" : "Recherche actualisée requise à l’envoi")
    end

    def content_steps
      present = %w[bbcode nfo].all? { |kind| @snapshot.contents[kind]&.body.present? }
      [ item("content", "Description et NFO", state: "pending", note: present ? "Texte conservé · validation requise" : "Compléter les textes requis") ]
    end

    def optional_steps
      draft = @snapshot.snapshots["draft"]
      ai = @release.ai_runs.order(:id).last
      [ item("draft", "Brouillon C411", required: false, owner: "C411", state: draft && !draft.remote_deleted ? "done" : "optional", note: "Facultatif pour la publication"),
        item("ai", "Aide à la rédaction", required: false, state: ai&.status == "succeeded" ? "done" : "optional", note: "L’aide IA reste facultative") ]
    end

    def outcomes
      [ item("publication", "Publication", owner: "C411", state: @release.publication_state == "published" ? "done" : "pending", note: "Envoi explicite du livre sélectionné"),
        item("seeding", "Premier seeding", state: @release.seeding_state == "succeeded" ? "done" : "pending", note: "Vérification initiale du torrent C411") ]
    end

    def warnings
      @snapshot.findings.select { |finding| finding.severity == "uncertainty" }.map do |finding|
        acknowledged = finding.finding_acknowledgements.max_by(&:id)&.acknowledged || false
        item("finding_#{finding.id}", finding.message, state: acknowledged ? "done" : "pending", owner: "Vous",
          checked: acknowledged, finding: finding, note: "Incertitude · version #{finding.number}")
      end
    end
  end
end
