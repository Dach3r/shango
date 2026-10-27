import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger", "panel"];

  connect() {
    this.close = this.close.bind(this);
    this.onKeydown = (event) => event.key === "Escape" && this.close();
    this.onClickOutside = (event) => !this.element.contains(event.target) && this.close();
  }

  toggle() {
    this.element.hasAttribute("data-open") ? this.close() : this.open();
  }

  open() {
    this.element.setAttribute("data-open", "");
    this.triggerTarget.setAttribute("aria-expanded", "true");
    this.panelTarget.removeAttribute("inert");
    document.addEventListener("keydown", this.onKeydown);
    document.addEventListener("click", this.onClickOutside);
  }

  close() {
    this.element.removeAttribute("data-open");
    this.triggerTarget.setAttribute("aria-expanded", "false");
    this.panelTarget.setAttribute("inert", "");
    document.removeEventListener("keydown", this.onKeydown);
    document.removeEventListener("click", this.onClickOutside);
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown);
    document.removeEventListener("click", this.onClickOutside);
  }
}
