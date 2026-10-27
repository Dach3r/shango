import { Controller } from "@hotwired/stimulus";

// Keeps the submit button disabled until the typed text matches the expected phrase.
export default class extends Controller {
  static targets = ["input", "submit", "check"];
  static values = { phrase: String, locked: Boolean };

  connect() {
    this.refresh();
  }

  refresh() {
    const match = this.inputTarget.value.trim().toLowerCase() === this.phraseValue.toLowerCase();
    this.submitTarget.disabled = this.lockedValue || !match;
    this.checkTarget.classList.toggle("opacity-0", !match);
  }
}
