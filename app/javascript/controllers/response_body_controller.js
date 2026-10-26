import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["editor", "frame", "mode"];
  static values = { raw: String, pretty: String };

  show(event) {
    const mode = event.params.mode;
    this.modeTargets.forEach((button) =>
      button.setAttribute(
        "aria-pressed",
        String(button.dataset.responseBodyModeParam === mode),
      ),
    );

    if (this.hasFrameTarget) {
      this.frameTarget.hidden = mode !== "preview";
      this.editorTarget.hidden = mode === "preview";
    }
    if (mode === "pretty") this.editor()?.setValue(this.prettyValue);
    if (mode === "raw")
      this.editor()?.setValue(this.rawValue || this.prettyValue);
  }

  async copy(event) {
    const button = event.currentTarget;
    await navigator.clipboard.writeText(this.rawValue || this.prettyValue);
    const label = button.querySelector("[data-label]") || button;
    const original = label.textContent;
    label.textContent = button.dataset.copiedLabel;
    setTimeout(() => {
      label.textContent = original;
    }, 1800);
  }

  editor() {
    return this.application.getControllerForElementAndIdentifier(
      this.editorTarget,
      "code-editor",
    );
  }
}
