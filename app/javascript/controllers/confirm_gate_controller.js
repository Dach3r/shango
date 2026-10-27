import { Controller } from "@hotwired/stimulus";

// Keeps the submit button disabled until the acknowledgement is checked and a password is typed.
export default class extends Controller {
  static targets = ["acknowledge", "password", "submit"];
  static values = { locked: Boolean };

  connect() {
    this.refresh();
  }

  refresh() {
    const ready = this.acknowledgeTarget.checked && this.passwordTarget.value !== "";
    this.submitTarget.disabled = this.lockedValue || !ready;
  }
}
