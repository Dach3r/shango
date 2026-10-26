import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.scrollIntoView({ inline: "nearest", block: "nearest" });
  }

  // Browsers reserve Cmd/Ctrl+W, so it only works as an installed app; in a browser tab Option/Alt+W is used instead.
  closeCurrent(event) {
    if (event.code !== "KeyW" || !this.#shortcut(event)) return;

    const close = this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.querySelector("[data-request-tab-close]");
    if (!close) return;

    event.preventDefault();
    close.click();
  }

  #shortcut(event) {
    if (event.shiftKey) return false;
    if (!this.#standalone()) return event.altKey && !event.metaKey && !event.ctrlKey;

    const mac = navigator.platform.startsWith("Mac");
    return !event.altKey && (mac ? event.metaKey && !event.ctrlKey : event.ctrlKey && !event.metaKey);
  }

  #standalone() {
    return window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
  }
}
