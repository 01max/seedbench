import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "status", "error", "conflict", "serverValues"]
  static values = { releaseId: Number, previousUrl: String, nextUrl: String, messages: Object }

  connect() {
    this.connected = true
    this.baseline = JSON.stringify(this.valuesFromForm())
    this.dirty = false
    this.unloadGuard = event => this.beforeUnload(event)
    this.bypassedForms = new WeakSet()
    this.restoreDraft()
    this.element.dataset.editorReady = "true"
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timer)
    this.previewRequest?.abort()
    window.removeEventListener("beforeunload", this.unloadGuard)
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
    this.dirty = Boolean(this.saving) || JSON.stringify(this.valuesFromForm()) !== this.baseline
    this.setStatus(this.dirty ? this.messagesValue.pending : this.messagesValue.saved)
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
    this.syncUnloadGuard()
  }

  syncUnloadGuard() {
    if (this.connected && (this.dirty || this.saving)) window.addEventListener("beforeunload", this.unloadGuard)
    else window.removeEventListener("beforeunload", this.unloadGuard)
  }

  save() {
    if (this.saving) return this.saving
    if (this.conflicted) return Promise.resolve(false)
    if (!this.dirty) return Promise.resolve(true)
    this.saving = this.performSave().finally(() => {
      this.saving = null
      this.syncUnloadGuard()
    })
    return this.saving
  }

  async performSave() {
    const captured = this.valuesFromForm()
    this.setStatus(this.messagesValue.saving)
    this.errorTarget.hidden = true
    try {
      const response = await fetch(this.formTarget.action, {
        method: "PATCH", body: new FormData(this.formTarget), credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const data = await response.json()
      if (!response.ok) {
        if (response.status === 409) this.showConflict(data)
        this.showError(data.message || data.error || this.messagesValue.refused)
        return false
      }
      this.acceptSave(data.revision, captured)
      return true
    } catch {
      this.showError(this.messagesValue.failed)
      return false
    }
  }

  acceptSave(revision, captured) {
    this.updateRevision(revision)
    this.baseline = JSON.stringify(captured)
    this.dirty = JSON.stringify(this.valuesFromForm()) !== this.baseline
    this.conflicted = false
    this.conflictTarget.hidden = true
    this.setStatus(this.dirty ? this.messagesValue.pending : this.messagesValue.saved)
    this.element.querySelector(".release-heading h1").textContent = captured.title
    const selected = this.element.querySelector('.queue-row[aria-current="page"] .queue-title')
    if (selected) selected.textContent = captured.title
    this.remember()
    this.schedule()
  }

  updateRevision(revision) {
    this.revisionInput.value = revision
    this.element.querySelectorAll('[name="mark[expected_revision]"], [data-release-revision]').forEach(input => { input.value = revision })
  }

  evidenceLoaded(event) {
    const frame = event.target
    const publication = frame.querySelector("[data-publication-state]")
    const publish = this.element.querySelector("[data-publish-action]")
    if (publication && publish) publish.disabled = !["unpublished", "failed"].includes(publication.dataset.publicationState)
    const preparation = frame.querySelector("[data-preparation-state]")
    if (preparation) {
      this.refreshPreparation(frame, preparation)
      this.preparationCompleted(preparation)
      return
    }
    const metadata = frame.querySelector("[data-evidence-revision]")
    if (!metadata) return
    if (!frame.querySelector("[data-status-sequence]")) frame.dispatchEvent(new CustomEvent("evidence:updated", { bubbles: true }))
    const revision = Number(metadata.dataset.evidenceRevision)
    if (revision <= Number(this.revisionInput.value)) return
    const values = JSON.parse(metadata.dataset.reviewedValues || "null")
    if (!values) return
    this.currentServer = { current_revision: revision, values }
    if (this.dirty || this.saving) this.showConflict(this.currentServer)
    else this.useServer()
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    this.setStatus(this.messagesValue.unsaved)
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
    this.setStatus(this.messagesValue.server_loaded)
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
    if (this.conflicted || !this.connected) return false
    while (this.dirty || this.saving) {
      if (!(await this.save())) return false
      clearTimeout(this.timer)
    }
    return true
  }

  async beforeSubmit(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    const reviewRevision = form.querySelector('[name="mark[expected_revision]"], [data-release-revision]')
    if (reviewRevision) reviewRevision.value = this.revisionInput.value
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
      if (await this.flush() && this.connected) window.Turbo.visit(url)
    } finally {
      this.navigating = false
    }
  }

  next() {
    this.navigate(this.nextUrlValue)
  }

  async performAction(url) {
    if (!(await this.flush()) || !this.connected) return
    try {
      const response = await fetch(url, {
        method: "PATCH", body: new FormData(this.formTarget), credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const data = await response.json()
      if (response.status === 409) this.showConflict(data)
      if (response.ok && data.values && Number(data.revision) >= Number(this.revisionInput.value)) {
        if (this.dirty || this.saving) this.showConflict({ current_revision: data.revision, values: data.values })
        else {
          this.writeValues(data.values)
          this.acceptSave(data.revision, this.valuesFromForm())
        }
      }
      if (response.ok || Array.isArray(data.reasons)) this.element.dispatchEvent(new CustomEvent("workbench:action", { bubbles: true }))
      this.errorTarget.textContent = data.message || this.messagesValue.action_completed
      this.errorTarget.hidden = false
    } catch {
      this.errorTarget.textContent = this.messagesValue.action_failed
      this.errorTarget.hidden = false
    }
  }

  preparationCompleted(metadata) {
    if (metadata.dataset.preparationState !== "prepared" || !metadata.dataset.preparationApprovedRevision) return
    const approved = Number(metadata.dataset.preparationApprovedRevision)
    const completed = Number(metadata.dataset.preparationCompletedRevision)
    const observed = Number(metadata.dataset.preparationObservedRevision)
    if (Number(this.revisionInput.value) !== approved || observed !== completed) return
    if (this.dirty || this.saving) this.showConflict({ current_revision: completed, values: JSON.parse(this.baseline) })
    else this.updateRevision(completed)
  }

  refreshPreparation(frame, metadata) {
    const state = metadata.dataset.preparationState
    if (!state || frame.id.includes("preparation")) return
    const button = this.element.querySelector('[data-prepare-allowed]')
    if (button) {
      button.disabled = state === "running" || button.dataset.prepareAllowed !== "true"
      if (metadata.dataset.hasPreparation === "true") button.textContent = button.dataset.reprepareLabel
    }
    const sequence = frame.querySelector("[data-status-sequence]")?.dataset.statusSequence
    if (state === "running" || sequence === this.preparationSequence) return
    this.preparationSequence = sequence
    const files = this.element.querySelector("turbo-frame[data-preparation-url]")
    if (!files) return
    if (files.src) files.reload()
    else files.src = files.dataset.preparationUrl
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
    const panel = this.element.querySelector("#panel-preview")
    if (!panel || panel.hidden) return
    this.loadPreview(values.bbcode)
  }

  async loadPreview(source) {
    this.previewRequest?.abort()
    const request = new AbortController()
    this.previewRequest = request
    const panel = this.element.querySelector("[data-preview-url]")
    const error = panel.querySelector("[data-preview-error]")
    try {
      const response = await fetch(panel.dataset.previewUrl, {
        method: "POST", credentials: "same-origin", signal: request.signal,
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify({ preview: { bbcode: source } })
      })
      if (!response.ok) throw new Error()
      const data = await response.json()
      if (!this.connected || request !== this.previewRequest || this.valuesFromForm().bbcode !== source) return
      panel.querySelector("[data-preview-output]").innerHTML = data.html
      error.textContent = data.errors.join(" ")
      error.hidden = data.errors.length === 0
    } catch (failure) {
      if (failure.name === "AbortError" || request !== this.previewRequest) return
      error.textContent = this.messagesValue.preview_failed
      error.hidden = false
    }
  }

  remember() {
    try {
      if (this.dirty) {
        sessionStorage.setItem(this.storageKey, JSON.stringify({ revision: Number(this.revisionInput.value), values: this.valuesFromForm() }))
      } else {
        sessionStorage.removeItem(this.storageKey)
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
      this.setStatus(this.messagesValue.draft_restored)
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
