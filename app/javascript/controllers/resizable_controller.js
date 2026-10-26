import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "api-client:response-height";
const MIN_HEIGHT = 120;
const KEY_STEP = 24;

// Drag the handle to resize the panel. It can grow until only the bounds
// element (the URL bar) stays visible above it. Double click restores the default height.
export default class extends Controller {
  static targets = ["panel", "bounds"];

  connect() {
    const saved = this.recall();
    if (saved) this.apply(saved);
    this.onWindowResize = () => this.apply(this.panelTarget.offsetHeight);
    window.addEventListener("resize", this.onWindowResize);
  }

  disconnect() {
    window.removeEventListener("resize", this.onWindowResize);
    this.stop();
  }

  start(event) {
    event.preventDefault();
    this.startY = event.clientY;
    this.startHeight = this.panelTarget.offsetHeight;
    this.onMove = (move) => this.apply(this.startHeight + this.startY - move.clientY);
    this.onEnd = () => {
      this.stop();
      this.remember();
    };
    document.addEventListener("pointermove", this.onMove);
    document.addEventListener("pointerup", this.onEnd);
    document.body.classList.add("select-none", "cursor-row-resize");
  }

  reset() {
    this.panelTarget.style.height = "";
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (_) {
      /* storage unavailable */
    }
  }

  key(event) {
    const delta = { ArrowUp: KEY_STEP, ArrowDown: -KEY_STEP }[event.key];
    if (!delta) return;

    event.preventDefault();
    this.apply(this.panelTarget.offsetHeight + delta);
    this.remember();
  }

  stop() {
    if (!this.onMove) return;

    document.removeEventListener("pointermove", this.onMove);
    document.removeEventListener("pointerup", this.onEnd);
    document.body.classList.remove("select-none", "cursor-row-resize");
    this.onMove = null;
  }

  apply(height) {
    const clamped = Math.round(Math.min(Math.max(height, MIN_HEIGHT), this.maxHeight()));
    this.panelTarget.style.height = `${clamped}px`;
  }

  maxHeight() {
    const available =
      this.element.getBoundingClientRect().bottom -
      this.boundsTarget.getBoundingClientRect().bottom;
    return Math.max(available, MIN_HEIGHT);
  }

  remember() {
    try {
      localStorage.setItem(STORAGE_KEY, String(this.panelTarget.offsetHeight));
    } catch (_) {
      /* storage unavailable */
    }
  }

  recall() {
    try {
      return Number(localStorage.getItem(STORAGE_KEY)) || null;
    } catch (_) {
      return null;
    }
  }
}
