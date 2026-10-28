import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } };

  connect() {
    this.remaining = this.delayValue;
    this.start();
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  pause() {
    clearTimeout(this.timer);
    this.remaining -= Date.now() - this.startedAt;
  }

  resume() {
    this.start();
  }

  close() {
    clearTimeout(this.timer);
    this.element.dataset.state = "closed";
    this.element.addEventListener(
      "transitionend",
      () => this.element.remove(),
      { once: true },
    );
    setTimeout(() => this.element.remove(), 300);
  }

  start() {
    this.startedAt = Date.now();
    this.timer = setTimeout(() => this.close(), this.remaining);
  }
}
