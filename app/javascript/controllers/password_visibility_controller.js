import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "show", "hide"]

  toggle() {
    const reveal = this.inputTarget.type === "password"
    this.inputTarget.type = reveal ? "text" : "password"
    this.showTarget.classList.toggle("hidden", reveal)
    this.hideTarget.classList.toggle("hidden", !reveal)
  }
}
