import { Controller } from "@hotwired/stimulus"

// Auth type picker: only the selected strategy's fields are visible and submitted.
export default class extends Controller {
  static targets = ["select", "section"]

  connect() {
    this.render()
  }

  change() {
    this.render()
  }

  render() {
    const type = this.selectTarget.value

    this.sectionTargets.forEach((section) => {
      const active = section.dataset.type === type
      section.hidden = !active
      section.querySelectorAll("input, textarea, select").forEach((field) => { field.disabled = !active })
      section.querySelector("[data-controller~='conditional-fields']")?.dispatchEvent(new CustomEvent("refresh"))
    })
  }
}
