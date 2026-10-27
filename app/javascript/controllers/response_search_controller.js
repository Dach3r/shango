import { Controller } from "@hotwired/stimulus";

const DEBOUNCE = 150;

export default class extends Controller {
  static targets = ["input", "count"];

  disconnect() {
    clearTimeout(this.timer);
  }

  input() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.run(), DEBOUNCE);
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.run(event.shiftKey ? "previous" : "next");
    } else if (event.key === "Escape") {
      this.clear();
    }
  }

  next() {
    this.run("next");
  }

  previous() {
    this.run("previous");
  }

  clear() {
    this.inputTarget.value = "";
    this.run();
  }

  run(direction) {
    clearTimeout(this.timer);
    const { total, current } =
      this.editor()?.search(this.inputTarget.value, direction) ?? {
        total: 0,
        current: 0,
      };

    this.element.dataset.empty = String(!this.inputTarget.value);
    this.countTarget.textContent = !this.inputTarget.value
      ? ""
      : total === 0
        ? "0"
        : `${current || "–"}/${total}`;
  }

  editor() {
    const editor = this.element
      .closest("[data-controller~='tabs']")
      ?.querySelector("[data-response-body-target='editor']");
    return (
      editor &&
      this.application.getControllerForElementAndIdentifier(
        editor,
        "code-editor",
      )
    );
  }
}
