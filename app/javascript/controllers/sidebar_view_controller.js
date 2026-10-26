import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "sidebar-view";

export default class extends Controller {
  static targets = ["collections", "history"];
  static values = { view: { type: String, default: "collections" } };

  connect() {
    if (this.recall() === "history") this.viewValue = "history";
    this.render();
  }

  showHistory() {
    this.viewValue = "history";
    this.remember();
  }

  showCollections() {
    this.viewValue = "collections";
    this.remember();
  }

  viewValueChanged() {
    this.render();
  }

  render() {
    const history = this.viewValue === "history";
    this.collectionsTargets.forEach((element) => {
      element.hidden = history;
    });
    this.historyTargets.forEach((element) => {
      element.hidden = !history;
    });
  }

  remember() {
    try {
      sessionStorage.setItem(STORAGE_KEY, this.viewValue);
    } catch (_) {
      /* storage unavailable */
    }
  }

  recall() {
    try {
      return sessionStorage.getItem(STORAGE_KEY);
    } catch (_) {
      return null;
    }
  }
}
