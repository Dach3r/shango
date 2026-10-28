import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["copy", "done"];
  static values = { text: String };

  async copy() {
    await navigator.clipboard.writeText(this.textValue);
    this.copyTarget.classList.add("hidden");
    this.doneTarget.classList.remove("hidden");
    setTimeout(() => {
      this.copyTarget.classList.remove("hidden");
      this.doneTarget.classList.add("hidden");
    }, 1800);
  }
}
