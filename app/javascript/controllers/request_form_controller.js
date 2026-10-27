import { Controller } from "@hotwired/stimulus";

const POLL_INTERVAL = 500;
const POLL_TIMEOUT = 180000;

export default class extends Controller {
  static targets = ["form", "send", "failure"];
  static values = {
    runUrl: String,
    curlUrl: String,
    requestId: String,
    methods: Object,
  };

  async run(event) {
    event?.preventDefault();
    if (this.running) return;

    this.running = true;
    this.formTarget.dispatchEvent(new CustomEvent("request-form:run"));
    this.abortController = new AbortController();
    this.setBusy(true);
    const body = new FormData(this.formTarget);
    body.delete("_method");

    try {
      const response = await fetch(this.runUrlValue, {
        method: "POST",
        body,
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
            ?.content,
        },
        credentials: "same-origin",
        signal: this.abortController.signal,
      });
      const queued = response.status === 202 && response.headers.get("X-Execution-Id");
      if (await this.render(response)) {
        if (queued) await this.poll(queued);
      }
    } catch (error) {
      if (error.name !== "AbortError") this.showFailure();
    } finally {
      this.running = false;
      this.abortController = null;
      this.executionId = null;
      this.setBusy(false);
    }
  }

  // Renders a Turbo Stream response; anything else is a failure. Returns whether it was a stream.
  async render(response) {
    const text = await response.text();
    if (response.headers.get("Content-Type")?.includes("turbo-stream")) {
      window.Turbo.renderStreamMessage(text);
      return true;
    }

    this.showFailure();
    return false;
  }

  // A queued run executes in a worker: ask for its result until it is ready (202 means still running).
  async poll(id) {
    this.executionId = id;
    const resultUrl = `${this.runUrlValue}/${id}/result`;
    const deadline = Date.now() + POLL_TIMEOUT;

    while (Date.now() < deadline) {
      await this.sleep(POLL_INTERVAL);
      const response = await fetch(resultUrl, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin",
        signal: this.abortController.signal,
      });
      if (response.status === 202) continue;
      if (response.status === 204) return;

      await this.render(response);
      return;
    }

    this.showFailure();
  }

  sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  cancelQueued() {
    if (!this.executionId) return;

    fetch(`${this.runUrlValue}/${this.executionId}/cancellation`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          ?.content,
      },
      credentials: "same-origin",
    });
  }

  toggle(event) {
    if (this.running) {
      event.preventDefault();
      this.cancelQueued();
      this.abortController.abort();
    } else {
      this.run(event);
    }
  }

  showFailure() {
    const panel = document.getElementById("response_panel");
    if (panel && this.hasFailureTarget)
      panel.replaceChildren(this.failureTarget.content.cloneNode(true));
  }

  methodChanged(event) {
    const preset = this.methodsValue[event.target.value.toUpperCase()];
    if (!preset) return;

    document
      .querySelectorAll(`[data-method-badge="${this.requestIdValue}"]`)
      .forEach((badge) => {
        badge.textContent = preset.label;
        badge.className = preset.classes;
      });
  }

  save(event) {
    event.preventDefault();
    this.formTarget.requestSubmit();
  }

  async copyCurl(event) {
    const button = event.currentTarget;
    const response = await fetch(this.curlUrlValue, {
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    });
    const { curl, error } = await response.json();
    if (error) return this.flash(button, error);

    await navigator.clipboard.writeText(curl);
    this.flash(button, button.dataset.copiedLabel);
  }

  setBusy(busy) {
    if (!this.hasSendTarget) return;

    this.sendTarget.dataset.busy = String(busy);
  }

  flash(button, text) {
    const label = button.querySelector("[data-label]") || button;
    const original = label.textContent;
    label.textContent = text;
    button.title = text;
    setTimeout(() => {
      label.textContent = original;
      button.removeAttribute("title");
    }, 1800);
  }
}
