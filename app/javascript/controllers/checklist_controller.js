import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.autoSubmit = "true"
  }

  submit(event) {
    event.currentTarget.form.requestSubmit()
  }
}
