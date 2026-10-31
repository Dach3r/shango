import { Controller } from "@hotwired/stimulus";

// Command palette: Cmd/Ctrl+K (or the status bar button) opens a dialog that searches pages, requests and monitors.
// The results come from the server into a Turbo Frame; arrows move the selection and Enter follows the selected link.
export default class extends Controller {
  static targets = ["dialog", "input", "frame", "item"];
  static values = { url: String };

  connect() {
    this.onKeydown = (event) => {
      if ((event.metaKey || event.ctrlKey) && !event.altKey && !event.shiftKey && event.key.toLowerCase() === "k") {
        event.preventDefault();
        this.dialogTarget.open ? this.dialogTarget.close() : this.open();
      }
    };
    document.addEventListener("keydown", this.onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown);
    clearTimeout(this.timer);
  }

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal();
    this.inputTarget.value = "";
    this.load("");
    this.inputTarget.focus();
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close();
  }

  search() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.load(this.inputTarget.value.trim()), 150);
  }

  load(query) {
    this.frameTarget.src = `${this.urlValue}?q=${encodeURIComponent(query)}`;
  }

  loaded() {
    this.select(0);
  }

  hover(event) {
    this.select(this.itemTargets.indexOf(event.currentTarget));
  }

  navigate(event) {
    const step = { ArrowDown: 1, ArrowUp: -1 }[event.key];
    if (step) {
      event.preventDefault();
      const count = this.itemTargets.length;
      if (count) this.select((this.index + step + count) % count);
    } else if (event.key === "Enter") {
      event.preventDefault();
      this.itemTargets[this.index]?.click();
    }
  }

  select(index) {
    this.index = index;
    this.itemTargets.forEach((item, position) => {
      item.setAttribute("aria-selected", String(position === index));
      if (position === index) item.scrollIntoView({ block: "nearest" });
    });
  }
}
