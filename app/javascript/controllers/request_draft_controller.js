import { Controller } from "@hotwired/stimulus";

const DELAY = 2000;

// Autosaves the editor as the request's draft on the server so edits survive switching tabs and reloads. The request
// itself is only written by Save. One request is in flight at a time; edits made meanwhile go out right after it.
export default class extends Controller {
  static values = { url: String, saving: String, saved: String, error: String };

  connect() {
    this.snapshot = this.#serialize();
    this.initial = this.snapshot;
    this.timer = null;
    this.sending = false;
    this.queued = false;
    this.tab = this.#currentTab();
    this.serverDirty = this.tab?.dataset.dirty !== undefined;
  }

  disconnect() {
    this.leave();
  }

  schedule() {
    this.#markDirty(this.serverDirty || this.#serialize() !== this.initial);
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
    this.queued = false;
    this.snapshot = this.#serialize();
    this.#markDirty(false);
    this.#status("");
  }

  // The tab asks before closing while the editor holds edits that are not saved.
  #markDirty(dirty) {
    this.tab?.toggleAttribute("data-dirty", dirty);
  }

  #currentTab() {
    return document.querySelector("[data-request-tab] [aria-current=page]")?.closest("[data-request-tab]");
  }

  #flush(keepalive) {
    clearTimeout(this.timer);
    this.timer = null;
    if (this.sending && !keepalive) {
      this.queued = true;
      return;
    }

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

    this.sending = true;
    this.#status(this.savingValue);
    try {
      const response = await request({ keepalive });
      this.#status(response.ok ? this.savedValue : this.errorValue);
    } catch {
      // keepalive requests are capped at 64 KB; retry a bigger one the regular way.
      if (keepalive) request({}).catch(() => {});
      this.#status(this.errorValue);
    } finally {
      this.sending = false;
      if (this.queued) {
        this.queued = false;
        this.#flush(false);
      }
    }
  }

  #status(text) {
    const status = document.getElementById("draft_status");
    if (!status) return;

    status.textContent = text;
    status.classList.toggle("animate-pulse", text === this.savingValue);
  }

  #formData() {
    const body = new FormData(this.element);
    for (const [name, value] of [...body]) if (value instanceof File) body.delete(name);
    body.delete("_method");
    body.delete("place");
    // Settings are autosaved by their own controller.
    for (const name of [...body.keys()]) if (name.startsWith("api_request[settings]")) body.delete(name);
    return body;
  }

  #serialize() {
    return JSON.stringify([...this.#formData()]);
  }
}
