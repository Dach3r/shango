import { Controller } from "@hotwired/stimulus";

const NAVIGATE_DELAY = 220;

export default class extends Controller {
  static values = { url: String, param: String, href: String };

  disconnect() {
    clearTimeout(this.timer);
  }

  // A request row is a link: hold the navigation briefly so a double click can rename instead.
  navigate(event) {
    if (this.editing) return;

    event.preventDefault();
    event.stopPropagation();
    clearTimeout(this.timer);
    this.timer = setTimeout(
      () => window.Turbo.visit(this.hrefValue),
      NAVIGATE_DELAY,
    );
  }

  edit(event) {
    event.preventDefault();
    event.stopPropagation();
    this.begin();
  }

  begin() {
    if (this.editing) return;

    clearTimeout(this.timer);
    this.editing = true;
    this.original = this.element.textContent.trim();
    this.draggable = this.element.closest("[draggable]");
    if (this.draggable) this.draggable.draggable = false;

    const input = document.createElement("input");
    input.type = "text";
    input.value = this.original;
    input.className =
      "w-full min-w-0 rounded border border-accent bg-field px-1 text-sm text-ink outline-none";
    ["click", "dblclick", "keydown", "keyup", "mousedown"].forEach((name) =>
      input.addEventListener(name, (e) => e.stopPropagation()),
    );
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") input.blur();
      if (e.key === "Escape") {
        input.value = this.original;
        input.blur();
      }
    });
    input.addEventListener("blur", () => this.commit(input));
    this.element.textContent = "";
    this.element.append(input);
    // Wait for the menu click to finish so closing the menu does not steal the focus back.
    setTimeout(() => {
      input.focus();
      input.select();
    });
  }

  async commit(input) {
    const name = input.value.trim();
    if (!name || name === this.original) return this.restore(this.original);

    this.restore(name);
    const body = new URLSearchParams({ [`${this.paramValue}[name]`]: name });
    const response = await fetch(this.urlValue, {
      method: "PATCH",
      body,
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          ?.content,
      },
      credentials: "same-origin",
    });
    if (response.ok)
      window.Turbo.visit(window.location.href, { action: "replace" });
    else this.restore(this.original);
  }

  restore(text) {
    this.element.textContent = text;
    if (this.draggable) this.draggable.draggable = true;
    this.editing = false;
  }
}
