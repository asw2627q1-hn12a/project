import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleInvalid = (event) => this.setMessage(event.target)
    this.clearMessage = (event) => event.target.setCustomValidity?.("")
    this.element.addEventListener("invalid", this.handleInvalid, true)
    this.element.addEventListener("input", this.clearMessage)
    this.element.addEventListener("change", this.clearMessage)
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.handleInvalid, true)
    this.element.removeEventListener("input", this.clearMessage)
    this.element.removeEventListener("change", this.clearMessage)
  }

  setMessage(field) {
    field.setCustomValidity("")
    const validity = field.validity

    if (validity.valueMissing) {
      field.setCustomValidity("Please fill out this field.")
    } else if (validity.typeMismatch && field.type === "url") {
      field.setCustomValidity("Please enter a valid URL.")
    } else if (validity.typeMismatch && field.type === "email") {
      field.setCustomValidity("Please enter a valid email address.")
    } else if (validity.tooLong) {
      field.setCustomValidity(`Please use no more than ${field.maxLength} characters.`)
    } else if (validity.tooShort) {
      field.setCustomValidity(`Please use at least ${field.minLength} characters.`)
    } else if (!validity.valid) {
      field.setCustomValidity("Please enter a valid value.")
    }
  }
}
