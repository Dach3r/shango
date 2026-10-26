import { Controller } from "@hotwired/stimulus";

// Right-hand panel that hosts a Turbo Frame. Links targeting the frame call open() with a title param.
export default class extends Controller {
  static targets = ["panel", "title"];

  open({ params: { title } }) {
    this.titleTarget.textContent = title || "";
    this.panelTarget.hidden = false;
  }

  // Re-clicking the trigger of the panel that is already showing closes it instead of reloading it.
  toggle(event) {
    if (!this.panelTarget.hidden && this.titleTarget.textContent === event.params.title) {
      event.preventDefault();
      this.close();
    } else {
      this.open(event);
    }
  }

  close() {
    this.panelTarget.hidden = true;
  }
}
