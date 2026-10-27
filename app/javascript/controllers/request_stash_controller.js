import { Controller } from "@hotwired/stimulus";

const DELAY = 600;

// Keeps the editor's unsaved state on the server (cache, not the database) so it survives switching tabs.
export default class extends Controller {
  static values = { url: String };

  connect() {
    this.snapshot = this.#serialize();
    this.timer = null;
  }

  disconnect() {
    this.leave();
  }

  schedule() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.#flush(false), DELAY);
  }

  // Sends what is pending right away, so a quick tab switch does not lose the last keystrokes.
  leave() {
    if (this.timer) this.#flush(true);
  }

  // A save or send persists the edits, so there is nothing left to keep.
  stop() {
    clearTimeout(this.timer);
    this.timer = null;
    this.snapshot = this.#serialize();
  }

  #flush(keepalive) {
    clearTimeout(this.timer);
    this.timer = null;
    const state = this.#serialize();
    if (state === this.snapshot) return;

    this.snapshot = state;
    this.#send(keepalive);
  }

  async #send(keepalive) {
    const request = (options) =>
      fetch(this.urlValue, {
        method: "PATCH",
        body: this.#formData(),
        headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
        credentials: "same-origin",
        ...options,
      });

    try {
      await request({ keepalive });
    } catch {
      // keepalive requests are capped at 64 KB; retry a bigger one the regular way.
      if (keepalive) request({}).catch(() => {});
    }
  }

  #formData() {
    const body = new FormData(this.element);
    for (const [name, value] of [...body]) if (value instanceof File) body.delete(name);
    body.delete("_method");
    body.delete("place");
    return body;
  }

  #serialize() {
    return JSON.stringify([...this.#formData()]);
  }
}
