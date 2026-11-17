import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "search", "filter", "fallback", "help", "helpButton"]

  connect() {
    this.fallbackTarget.hidden = true
    this.helpButtonTarget.hidden = false
    const { queueFocus, queuePending } = this.formTarget.dataset
    if (queueFocus) this.restoreFocus(JSON.parse(queueFocus))
    if (queuePending) this.scheduleSearch()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  scheduleSearch(event) {
    clearTimeout(this.timer)
    if (!event?.isComposing) this.timer = setTimeout(() => this.submitFilters(), 250)
  }

  submitFilters() {
    clearTimeout(this.timer)
    this.formTarget.requestSubmit()
  }

  recordFilterRequest({ detail: { url } }) {
    this.requested = { query: (url.searchParams.get("q") || "").trim(), state: url.searchParams.get("state") }
    if (this.sameFilters(this.formTarget, this.requested)) clearTimeout(this.timer)
  }

  preserveFilters({ detail: { newBody } }) {
    const incoming = newBody.querySelector(".queue-search")
    if (!incoming || !this.requested || !this.sameFilters(incoming, this.requested)) return

    const focused = document.activeElement
    const pending = !this.sameFilters(this.formTarget, this.requested)
    if (pending || focused === this.searchTarget) incoming.elements.q.value = this.searchTarget.value
    if (pending) {
      incoming.elements.state.value = this.filterTarget.value
      incoming.dataset.queuePending = "true"
    }
    if (focused === this.searchTarget || focused === this.filterTarget) {
      incoming.dataset.queueFocus = JSON.stringify({ name: focused.name, start: focused.selectionStart, end: focused.selectionEnd })
    }
  }

  sameFilters(form, filters) {
    return form.elements.q.value.trim() === filters.query && form.elements.state.value === filters.state
  }

  restoreFocus({ name, start, end }) {
    const field = this.formTarget.elements.namedItem(name)
    field.focus({ preventScroll: true })
    if (field === this.searchTarget && start != null) field.setSelectionRange(start, end)
  }

  shortcut(event) {
    if (this.helpTarget.open || event.defaultPrevented || event.isComposing || event.repeat || event.ctrlKey || event.metaKey) return

    if (event.altKey) {
      this.navigateFromKey(event)
      return
    }
    if (event.target instanceof Element && event.target.closest("input, textarea, select, [contenteditable]")) return
    if (event.key === "/") {
      event.preventDefault()
      this.searchTarget.focus()
    } else if (event.key === "?") {
      event.preventDefault()
      this.openHelp()
    }
  }

  navigateFromKey(event) {
    if (event.shiftKey || event.target instanceof HTMLSelectElement) return

    const locations = {
      ArrowUp: '.queue-footer [rel="prev"]',
      ArrowDown: '.queue-footer [rel="next"]',
      PageUp: '.queue-pagination [rel="prev"]',
      PageDown: '.queue-pagination [rel="next"]'
    }
    const location = locations[event.key] && this.element.querySelector(locations[event.key])
    if (!location) return

    event.preventDefault()
    location.click()
  }

  openHelp() {
    if (!this.helpTarget.open) this.helpTarget.showModal()
  }

  closeHelp() {
    this.helpTarget.close()
  }
}
