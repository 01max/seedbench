import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.documentElement.dataset.theme = localStorage.getItem("seedbench.appearance") === "light" ? "light" : "dark"
  }

  toggle() {
    const theme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    localStorage.setItem("seedbench.appearance", theme)
    document.documentElement.dataset.theme = theme
  }
}
