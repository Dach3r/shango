import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "collections-sidebar-collapsed";

// Collapses and expands the collections sidebar from a status bar button. The choice survives navigation.
export default class extends Controller {
  static targets = ["panel", "button"];

  panelTargetConnected() {
    this.render(this.collapsed);
  }

  toggle() {
    const collapsed = !this.collapsed;
    try {
      localStorage.setItem(STORAGE_KEY, collapsed);
    } catch {
      // storage unavailable: the choice only lasts for this page
    }
    this.render(collapsed);
  }

  render(collapsed) {
    this.panelTargets.forEach((panel) => (panel.hidden = collapsed));
    this.buttonTargets.forEach((button) => button.setAttribute("aria-expanded", !collapsed));
  }

  get collapsed() {
    try {
      return localStorage.getItem(STORAGE_KEY) === "true";
    } catch {
      return false;
    }
  }
}
