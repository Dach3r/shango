import { Controller } from "@hotwired/stimulus";

// Right-hand panel that hosts a Turbo Frame. Links targeting the frame call open() with a title param; `bare` hides the header.
// The panel spans from the left edge of the first anchor target (the status bar switchers) to the window edge.
export default class extends Controller {
  static targets = ["panel", "overlay", "header", "title", "anchor"];

  connect() {
    this.resizeObserver = new ResizeObserver(() => this.syncWidth());
    this.anchorTargets.forEach((anchor) => this.resizeObserver.observe(anchor));
    this.resizeObserver.observe(document.body);
  }

  disconnect() {
    this.resizeObserver.disconnect();
  }

  open({ params: { title, bare } }) {
    this.titleTarget.textContent = title || "";
    this.headerTarget.hidden = !!bare;
    this.panelTarget.hidden = false;
    this.overlayTarget.hidden = false;
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
    this.overlayTarget.hidden = true;
  }

  syncWidth() {
    if (!this.hasAnchorTarget) return;

    const width = document.documentElement.clientWidth - this.anchorTarget.getBoundingClientRect().left;
    this.panelTarget.style.setProperty("--right-sidebar-width", `${Math.round(width)}px`);
  }
}
