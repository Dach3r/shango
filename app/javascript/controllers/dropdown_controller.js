import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger", "menu"];

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close();
  }

  open() {
    this.menuTarget.hidden = false;
    this.triggerTarget.setAttribute("aria-expanded", "true");
  }

  close() {
    this.menuTarget.hidden = true;
    this.triggerTarget.setAttribute("aria-expanded", "false");
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close();
  }

  closeOnEscape() {
    if (this.menuTarget.hidden) return;

    this.close();
    this.triggerTarget.focus();
  }
}
