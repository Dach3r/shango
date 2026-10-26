import { Controller } from "@hotwired/stimulus";

// Right-hand panel that hosts a Turbo Frame. Links targeting the frame call open() with a title param.
export default class extends Controller {
  static targets = ["panel", "title"];

  open({ params: { title } }) {
    this.titleTarget.textContent = title || "";
    this.panelTarget.hidden = false;
  }

  close() {
    this.panelTarget.hidden = true;
  }
}
