import { Controller } from "@hotwired/stimulus"

// Off-canvas sidebar below the lg breakpoint; always visible from lg up via CSS.
export default class extends Controller {
  static targets = ["panel", "backdrop", "trigger"]

  toggle() {
    this.panelTarget.classList.contains("-translate-x-full") ? this.open() : this.close()
  }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.backdropTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }
}
