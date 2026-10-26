import { Controller } from "@hotwired/stimulus";

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
      });
      const text = await response.text();
      if (response.headers.get("Content-Type")?.includes("turbo-stream")) {
        window.Turbo.renderStreamMessage(text);
      } else {
        this.showFailure();
      }
    } catch (_) {
      this.showFailure();
    } finally {
      this.running = false;
      this.setBusy(false);
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

    this.sendTarget.disabled = busy;
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
