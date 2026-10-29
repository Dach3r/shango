import { Controller } from "@hotwired/stimulus";

// Refreshes the page (a Turbo morph, so scroll and focus stay) every `interval` ms while the tab is visible.
export default class extends Controller {
  static values = { interval: { type: Number, default: 60000 } };

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  refresh() {
    if (document.visibilityState !== "visible") return;

    window.Turbo.visit(window.location.href, { action: "replace" });
  }
}
