import { Controller } from "@hotwired/stimulus";

// Right-hand panel that hosts a Turbo Frame. Links targeting the frame call open() with a title param.
// The panel spans from the left edge of the anchor target (the status bar's project switcher) to the window edge.
export default class extends Controller {
  static targets = ["panel", "title", "anchor"];

  connect() {
    this.resizeObserver = new ResizeObserver(() => this.syncWidth());
    this.anchorTargets.forEach((anchor) => this.resizeObserver.observe(anchor));
    this.resizeObserver.observe(document.body);
  }

  disconnect() {
    this.resizeObserver.disconnect();
  }

  open({ params: { title } }) {
    this.titleTarget.textContent = title || "";
    this.panelTarget.hidden = false;
    this.syncWidth();
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

  syncWidth() {
    if (!this.hasAnchorTarget) return;

    const width = document.documentElement.clientWidth - this.anchorTarget.getBoundingClientRect().left;
    this.panelTarget.style.setProperty("--right-sidebar-width", `${Math.round(width)}px`);
  }
}
