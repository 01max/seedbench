import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  show(event) {
    this.select(event.currentTarget.dataset.panel)
  }

  select(key) {
    this.panelTargets.forEach(panel => { panel.hidden = panel.dataset.panel !== key })
    this.tabTargets.forEach(tab => {
      const selected = tab.dataset.panel === key
      tab.setAttribute("aria-selected", String(selected))
      tab.tabIndex = selected ? 0 : -1
    })
    this.dispatch("shown", { detail: { key } })
  }

  navigate(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    const offset = event.key === "ArrowLeft" ? -1 : 1
    let next = (index + offset + this.tabTargets.length) % this.tabTargets.length
    if (event.key === "Home") next = 0
    if (event.key === "End") next = this.tabTargets.length - 1
    this.select(this.tabTargets[next].dataset.panel)
    this.tabTargets[next].focus()
  }
}
