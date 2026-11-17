import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "result"]
  static values = { url: String, pending: String, failed: String }

  connect() {
    this.revision = 0
    this.buttonTarget.disabled = false
  }

  clear() {
    this.revision += 1
    this.show("", "")
  }

  async run() {
    const button = this.buttonTarget
    const revision = this.revision
    const data = new FormData(this.element)
    data.delete("_method")
    data.delete("authenticity_token")
    button.disabled = true
    this.show("pending", this.pendingValue)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST", body: data, credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const { status, message } = await response.json()
      if (revision !== this.revision) return
      if (typeof status === "string" && typeof message === "string") this.show(status, message)
      else this.show("failed", this.failedValue)
    } catch {
      if (revision === this.revision) this.show("failed", this.failedValue)
    } finally {
      button.disabled = false
    }
  }

  show(status, message) {
    this.resultTarget.dataset.status = status
    this.resultTarget.textContent = message
  }
}
