import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "message"]
  static values = { messages: Object, url: String, interval: { type: Number, default: 1500 }, limit: { type: Number, default: 30 } }

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
      this.messageTarget.textContent = this.messagesValue.current
      return
    }
    if (this.attempts >= this.limit) {
      this.messageTarget.textContent = this.messagesValue.paused
      return
    }
    this.messageTarget.textContent = this.messagesValue.automatic
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
    const statusUrl = new URL(this.urlValue, document.baseURI).href
    if (this.frameTarget.src === statusUrl) this.frameTarget.reload()
    else this.frameTarget.src = statusUrl
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
    if (incoming < current) {
      event.detail.render = () => {}
      return
    }
    const opened = new Set(Array.from(this.frameTarget.querySelectorAll("details[open][data-detail-key]"), node => node.dataset.detailKey))
    event.detail.newFrame.querySelectorAll("details[data-detail-key]").forEach(node => { node.open = opened.has(node.dataset.detailKey) })
  }

  failed(event) {
    event.preventDefault()
    this.unavailable = true
    clearTimeout(this.timer)
    this.messageTarget.textContent = this.messagesValue.unavailable
  }
}
