import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "api-client:response-height-rem";
const LEGACY_STORAGE_KEY = "api-client:response-height";
const MIN_HEIGHT_REM = 7.5;
const KEY_STEP_REM = 1.5;

const rem = () => parseFloat(getComputedStyle(document.documentElement).fontSize);

// Drag the handle to resize the panel. It can grow until only the bounds
// element (the URL bar) stays visible above it. Double click restores the default height.
export default class extends Controller {
  static targets = ["panel", "bounds"];

  connect() {
    const saved = this.recall();
    if (saved) this.apply(saved * rem());
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
      localStorage.removeItem(LEGACY_STORAGE_KEY);
    } catch (_) {
      /* storage unavailable */
    }
  }

  key(event) {
    const step = { ArrowUp: KEY_STEP_REM, ArrowDown: -KEY_STEP_REM }[event.key];
    if (!step) return;

    event.preventDefault();
    this.apply(this.panelTarget.offsetHeight + step * rem());
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
    const clamped = Math.min(Math.max(height, MIN_HEIGHT_REM * rem()), this.maxHeight());
    this.panelTarget.style.height = `${clamped / rem()}rem`;
  }

  maxHeight() {
    const available =
      this.element.getBoundingClientRect().bottom -
      this.boundsTarget.getBoundingClientRect().bottom;
    return Math.max(available, MIN_HEIGHT_REM * rem());
  }

  remember() {
    try {
      localStorage.setItem(STORAGE_KEY, String(this.panelTarget.offsetHeight / rem()));
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
