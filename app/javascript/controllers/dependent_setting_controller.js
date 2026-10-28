import { Controller } from "@hotwired/stimulus";

// Hides and disables a dependent input while its switch is off; a mirror hidden field keeps the value submitted.
export default class extends Controller {
  static targets = ["switch", "input", "mirror"];

  connect() {
    this.update();
  }

  update() {
    const active = this.switchTarget.checked;
    this.mirrorTarget.value = this.inputTarget.value;
    this.inputTarget.disabled = !active;
    this.mirrorTarget.disabled = active;
    this.element.querySelector("[data-dependent-row]").hidden = !active;
  }
}
