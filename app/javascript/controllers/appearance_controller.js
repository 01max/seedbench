import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.apply(localStorage.getItem("seedbench.appearance") || "light")
  }

  toggleTargetConnected() {
    this.refresh()
  }

  toggle() {
    const theme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    localStorage.setItem("seedbench.appearance", theme)
    this.apply(theme)
  }

  apply(theme) {
    document.documentElement.dataset.theme = theme === "dark" ? "dark" : "light"
    this.refresh()
  }

  refresh() {
    const dark = document.documentElement.dataset.theme === "dark"
    this.toggleTargets.forEach(button => button.setAttribute("aria-checked", String(dark)))
  }
}
