import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "status", "error", "conflict", "serverValues"]
  static values = { releaseId: Number, previousUrl: String, nextUrl: String }

  connect() {
    this.connected = true
    this.baseline = JSON.stringify(this.valuesFromForm())
    this.dirty = false
    this.bypassedForms = new WeakSet()
    this.restoreDraft()
    this.element.dataset.editorReady = "true"
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timer)
  }

  valuesFromForm() {
    return Object.fromEntries(Array.from(this.formTarget.querySelectorAll("[data-edit-field]"), input => [input.dataset.editField, input.value]))
  }

  get revisionInput() {
    return this.formTarget.querySelector('[name="edit[expected_revision]"]')
  }

  get storageKey() {
    return `seedbench.release-draft.${this.releaseIdValue}`
  }

  change(event) {
    if (event.target.form !== this.formTarget) return
    this.dirty = JSON.stringify(this.valuesFromForm()) !== this.baseline
    this.setStatus(this.dirty ? "Modifications en attente" : "Enregistré")
    this.remember()
    this.schedule()
  }

  schedule() {
    clearTimeout(this.timer)
    if (this.dirty && !this.conflicted && this.connected) {
      this.timer = setTimeout(() => this.save(), 700)
    }
  }

  setStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.dataset.dirty = String(this.dirty)
  }

  save() {
    if (this.saving) return this.saving
    if (this.conflicted) return Promise.resolve(false)
    if (!this.dirty) return Promise.resolve(true)
    this.saving = this.performSave().finally(() => { this.saving = null })
    return this.saving
  }

  async performSave() {
    const captured = this.valuesFromForm()
    this.setStatus("Enregistrement…")
    this.errorTarget.hidden = true
    try {
      const response = await fetch(this.formTarget.action, {
        method: "PATCH", body: new FormData(this.formTarget), credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const data = await response.json()
      if (!response.ok) {
        if (response.status === 409) this.showConflict(data)
        this.showError(data.message || data.error || "Enregistrement refusé. Votre saisie est conservée.")
        return false
      }
      this.acceptSave(data.revision, captured)
      return true
    } catch {
      this.showError("Enregistrement impossible. Votre saisie est conservée. Vérifiez la connexion et réessayez.")
      return false
    }
  }

  acceptSave(revision, captured) {
    this.updateRevision(revision)
    this.baseline = JSON.stringify(captured)
    this.dirty = JSON.stringify(this.valuesFromForm()) !== this.baseline
    this.conflicted = false
    this.conflictTarget.hidden = true
    this.setStatus(this.dirty ? "Modifications en attente" : "Enregistré")
    this.element.querySelector(".release-heading h1").textContent = captured.title
    const selected = this.element.querySelector('.queue-row[aria-current="page"] .queue-title')
    if (selected) selected.textContent = captured.title
    this.remember()
    this.schedule()
  }

  updateRevision(revision) {
    this.revisionInput.value = revision
    this.element.querySelectorAll('[name="mark[expected_revision]"]').forEach(input => { input.value = revision })
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    this.setStatus("Non enregistré")
    this.remember()
  }

  showConflict(data) {
    this.conflicted = true
    this.currentServer = data
    this.conflictTarget.hidden = false
    this.serverValuesTarget.textContent = JSON.stringify(data.values, null, 2)
    clearTimeout(this.timer)
  }

  async keepMine() {
    if (!this.currentServer) return
    this.updateRevision(this.currentServer.current_revision)
    this.conflicted = false
    await this.flush()
  }

  useServer() {
    if (!this.currentServer) return
    this.writeValues(this.currentServer.values)
    this.updateRevision(this.currentServer.current_revision)
    this.baseline = JSON.stringify(this.valuesFromForm())
    this.dirty = false
    this.conflicted = false
    this.conflictTarget.hidden = true
    this.errorTarget.hidden = true
    this.setStatus("Version enregistrée chargée")
    this.forgetDraft()
    this.preview()
  }

  writeValues(values) {
    this.formTarget.querySelectorAll("[data-edit-field]").forEach(input => {
      if (typeof values[input.dataset.editField] === "string") input.value = values[input.dataset.editField]
    })
  }

  async flush() {
    clearTimeout(this.timer)
    if (this.conflicted) return false
    while (this.dirty || this.saving) {
      if (!(await this.save())) return false
      clearTimeout(this.timer)
    }
    return true
  }

  async beforeSubmit(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    if (this.bypassedForms.has(form)) {
      this.bypassedForms.delete(form)
      return
    }
    if (form === this.formTarget) {
      event.preventDefault()
      const action = event.submitter?.getAttribute("formaction")
      if (action) await this.performAction(action)
      else await this.flush()
      return
    }
    if (!this.dirty && !this.saving) return
    event.preventDefault()
    const submitter = event.submitter
    if (!(await this.flush()) || !form.isConnected) return
    this.bypassedForms.add(form)
    form.requestSubmit(submitter?.isConnected ? submitter : undefined)
  }

  beforeVisit(event) {
    if (!this.dirty && !this.saving) return
    event.preventDefault()
    this.navigate(event.detail.url)
  }

  async navigate(url) {
    if (!url || this.navigating) return
    this.navigating = true
    try {
      if (await this.flush()) window.Turbo.visit(url)
    } finally {
      this.navigating = false
    }
  }

  next() {
    this.navigate(this.nextUrlValue)
  }

  async performAction(url) {
    if (!(await this.flush())) return
    try {
      const response = await fetch(url, {
        method: "PATCH", body: new FormData(this.formTarget), credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const data = await response.json()
      if (response.status === 409) this.showConflict(data)
      if (data.revision !== undefined) this.updateRevision(data.revision)
      this.errorTarget.textContent = data.message || "Action terminée. Consultez les contrôles."
      this.errorTarget.hidden = false
    } catch {
      this.errorTarget.textContent = "Action impossible. Le texte enregistré reste conservé."
      this.errorTarget.hidden = false
    }
  }

  shortcut(event) {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
      event.preventDefault()
      this.flush()
    } else if (event.altKey && ["ArrowUp", "ArrowDown"].includes(event.key)) {
      event.preventDefault()
      this.navigate(event.key === "ArrowUp" ? this.previousUrlValue : this.nextUrlValue)
    }
  }

  preview() {
    const values = this.valuesFromForm()
    this.element.querySelectorAll("[data-preview-field]").forEach(node => { node.textContent = values[node.dataset.previewField] || "" })
  }

  remember() {
    try {
      if (this.dirty) {
        sessionStorage.setItem(this.storageKey, JSON.stringify({ revision: Number(this.revisionInput.value), values: this.valuesFromForm() }))
      } else {
        const draft = JSON.parse(sessionStorage.getItem(this.storageKey) || "null")
        if (!draft || JSON.stringify(draft.values) === this.baseline) sessionStorage.removeItem(this.storageKey)
      }
    } catch {
      // Editing remains available when browser storage is disabled or full.
    }
  }

  restoreDraft() {
    try {
      const draft = JSON.parse(sessionStorage.getItem(this.storageKey) || "null")
      if (!draft || !Number.isInteger(draft.revision) || !draft.values || typeof draft.values !== "object") return
      if (JSON.stringify(draft.values) === this.baseline) {
        sessionStorage.removeItem(this.storageKey)
        return
      }
      const server = { current_revision: Number(this.revisionInput.value), values: this.valuesFromForm() }
      this.writeValues(draft.values)
      this.revisionInput.value = draft.revision
      this.dirty = true
      this.setStatus("Saisie restaurée")
      if (draft.revision !== server.current_revision) this.showConflict(server)
      else this.schedule()
    } catch {
      // An unreadable browser draft never replaces server content.
    }
  }

  beforeUnload(event) {
    if (!this.dirty && !this.saving) return
    this.remember()
    event.preventDefault()
    event.returnValue = ""
  }

  forgetDraft() {
    try {
      sessionStorage.removeItem(this.storageKey)
    } catch {
      // Browser storage is optional for the active editor.
    }
  }
}
