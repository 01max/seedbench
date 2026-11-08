import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "message"]
  static values = { url: String, interval: { type: Number, default: 1500 }, limit: { type: Number, default: 30 } }

  connect() {
    this.connected = true
    this.attempts = 0
    this.schedule()
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timer)
  }

  get active() {
    return this.frameTarget.querySelector('[data-active-operations="true"]') !== null
  }

  get limit() {
    return Number.isFinite(this.limitValue) ? Math.min(30, Math.max(1, this.limitValue)) : 30
  }

  schedule() {
    clearTimeout(this.timer)
    if (!this.connected || this.formBusy || this.unavailable || document.hidden) return
    if (!this.active) {
      this.messageTarget.textContent = "État local à jour"
      return
    }
    if (this.attempts >= this.limit) {
      this.messageTarget.textContent = "Actualisation en pause"
      return
    }
    this.messageTarget.textContent = "Actualisation automatique"
    const interval = Number.isFinite(this.intervalValue) ? Math.max(1000, this.intervalValue) : 1500
    this.timer = setTimeout(() => this.load(), interval)
  }

  load() {
    if (!this.connected || this.formBusy || document.hidden) return
    if (this.frameTarget.hasAttribute("busy")) {
      this.schedule()
      return
    }
    this.attempts += 1
    this.element.dataset.statusPollCount = this.attempts
    if (this.frameTarget.src) this.frameTarget.reload()
    else this.frameTarget.src = this.urlValue
  }

  loaded() {
    this.schedule()
  }

  refresh() {
    clearTimeout(this.timer)
    this.attempts = 0
    this.unavailable = false
    this.load()
  }

  pause() {
    this.formBusy = true
    clearTimeout(this.timer)
  }

  resume() {
    this.formBusy = false
    this.schedule()
  }

  visibility() {
    this.schedule()
  }

  preserveNewer(event) {
    const current = Number(this.frameTarget.querySelector("[data-status-sequence]")?.dataset.statusSequence || 0)
    const incoming = Number(event.detail.newFrame.querySelector("[data-status-sequence]")?.dataset.statusSequence || 0)
    if (incoming < current) event.detail.render = () => {}
  }

  failed(event) {
    event.preventDefault()
    this.unavailable = true
    clearTimeout(this.timer)
    this.messageTarget.textContent = "Actualisation indisponible. Réessayez."
  }
}
