import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "choice", "result"]
  static values = { url: String, messages: Object }

  connect() {
    this.fields = ["connection[endpoint]", "connection[credentials][password]"].map(name => this.element.elements.namedItem(name))
    this.revision = 0
    this.buttonTarget.disabled = false
  }

  reset(event) {
    if (!this.fields.includes(event.target)) return

    this.revision += 1
    this.clearChoices()
    this.resultTarget.textContent = ""
  }

  async run() {
    if (!this.fields.every(field => field.reportValidity())) return

    const revision = this.revision
    const button = this.buttonTarget
    const data = new FormData()
    this.fields.forEach(field => data.append(field.name, field.value))
    this.clearChoices()
    this.resultTarget.textContent = this.messagesValue.pending
    button.disabled = true

    try {
      const response = await fetch(this.urlValue, {
        method: "POST", body: data, credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const { daemons, message } = await response.json()
      if (revision !== this.revision) return

      if (response.ok && Array.isArray(daemons)) this.showChoices(daemons)
      else this.resultTarget.textContent = message || this.messagesValue.failed
    } catch {
      if (revision === this.revision) this.resultTarget.textContent = this.messagesValue.failed
    } finally {
      button.disabled = false
    }
  }

  clearChoices() {
    this.choiceTarget.replaceChildren(this.choiceTarget.options[0])
    this.choiceTarget.value = ""
    this.choiceTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  showChoices(daemons) {
    for (const daemon of daemons) {
      const address = daemon.address.includes(":") && !daemon.address.startsWith("[") ? `[${daemon.address}]` : daemon.address
      const label = `${address}:${daemon.port}${daemon.username ? ` (${daemon.username})` : ""}`
      this.choiceTarget.add(new Option(label, daemon.id))
    }
    if (daemons.length === 1) this.choiceTarget.selectedIndex = 1
    const outcome = daemons.length === 0 ? "empty" : daemons.length === 1 ? "single" : "multiple"
    this.resultTarget.textContent = this.messagesValue[outcome]
  }
}
