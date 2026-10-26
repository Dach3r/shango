import { Controller } from "@hotwired/stimulus"

// Shows a field only when another field of the same group has one of the listed values:
// <div data-conditional-fields-target="field" data-show-when='{"grant_type": ["password"]}'>
// Hidden fields are disabled so they are not submitted.
export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.update()
  }

  update() {
    const inactiveSection = this.element.closest("[data-auth-form-target='section']")?.hidden

    this.fieldTargets.forEach((wrapper) => {
      const conditions = JSON.parse(wrapper.dataset.showWhen || "{}")
      const visible = Object.entries(conditions).every(([name, values]) => values.includes(this.valueOf(name)))
      wrapper.hidden = !visible
      wrapper.querySelectorAll("input, textarea, select").forEach((field) => { field.disabled = !visible || inactiveSection })
    })
  }

  valueOf(name) {
    return this.element.querySelector(`[data-field-name='${name}']`)?.value
  }
}
