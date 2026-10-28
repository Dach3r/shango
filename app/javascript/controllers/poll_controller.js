import { Controller } from "@hotwired/stimulus";

// Reloads the surrounding turbo-frame from `url` every `interval` ms. Each reload replaces this element, so polling
// stops by itself as soon as the server stops rendering it.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 1000 } };

  connect() {
    this.timer = setTimeout(() => this.refresh(), this.intervalValue);
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  refresh() {
    const frame = this.element.closest("turbo-frame");
    if (!frame) return;

    if (frame.src) frame.reload();
    else frame.src = this.urlValue;
  }
}
