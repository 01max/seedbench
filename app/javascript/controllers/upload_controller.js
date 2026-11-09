import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "trigger", "reset", "fallback", "error"]
  static values = { messages: Object }

  connect() {
    this.fallbackTargets.forEach(element => { element.hidden = true })
    this.triggerTarget.hidden = false
    this.element.dataset.uploadReady = "true"
  }

  choose() {
    if (this.inputTarget.files.length) this.element.requestSubmit()
    else this.inputTarget.click()
  }

  changeSelection() {
    this.inputTarget.value = ""
    this.inputTarget.click()
    this.updateSelection()
  }

  selected() {
    this.updateSelection()
    if (this.inputTarget.files.length) this.element.requestSubmit()
  }

  updateSelection() {
    const count = this.inputTarget.files.length
    this.triggerTarget.textContent = count ? this.message("selected", count) : this.messagesValue.add
    this.resetTarget.hidden = count === 0
    this.errorTarget.hidden = true
  }

  message(key, count) {
    return this.messagesValue[key][count === 1 ? "one" : "other"].replace("%{count}", String(count))
  }

  start() {
    this.element.setAttribute("aria-busy", "true")
    this.triggerTarget.disabled = true
    this.resetTarget.hidden = true
    this.triggerTarget.textContent = this.message("importing", this.inputTarget.files.length)
  }

  finish(event) {
    this.element.removeAttribute("aria-busy")
    this.triggerTarget.disabled = false
    this.updateSelection()
    if (!event.detail.success) this.showFailure()
  }

  failed(event) {
    event.preventDefault()
    this.element.removeAttribute("aria-busy")
    this.triggerTarget.disabled = false
    this.updateSelection()
    this.showFailure()
  }

  showFailure() {
    this.errorTarget.textContent = this.messagesValue.failed
    this.errorTarget.hidden = false
  }
}
