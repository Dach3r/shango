import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.scrollIntoView({ inline: "nearest", block: "nearest" });
  }

  // Browsers reserve Cmd/Ctrl+W, so the shortcut is Option/Alt+W.
  closeCurrent(event) {
    if (event.code !== "KeyW" || !event.altKey || event.shiftKey || event.metaKey || event.ctrlKey) return;

    const close = this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.querySelector("[data-request-tab-close]");
    if (!close) return;

    event.preventDefault();
    close.click();
  }
}
