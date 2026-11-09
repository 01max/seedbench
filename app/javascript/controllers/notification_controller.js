import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss() {
    const stack = this.element.parentElement
    this.element.remove()
    if (!stack.querySelector(".flash-message")) stack.remove()
  }
}
