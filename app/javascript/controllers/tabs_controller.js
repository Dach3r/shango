import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];
  static values = { active: String, key: String };

  connect() {
    const remembered = this.recall();
    if (
      remembered &&
      this.panelTargets.some((panel) => panel.dataset.name === remembered)
    )
      this.activeValue = remembered;
    this.render();
  }

  select(event) {
    this.activeValue = event.params.name;
    this.remember();
  }

  activeValueChanged() {
    this.render();
  }

  render() {
    this.tabTargets.forEach((tab) =>
      tab.setAttribute(
        "aria-selected",
        String(tab.dataset.name === this.activeValue),
      ),
    );
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.name !== this.activeValue;
    });
  }

  remember() {
    if (!this.keyValue) return;

    try {
      sessionStorage.setItem(`tabs:${this.keyValue}`, this.activeValue);
    } catch (_) {
      /* storage unavailable */
    }
  }

  recall() {
    if (!this.keyValue) return null;

    try {
      return sessionStorage.getItem(`tabs:${this.keyValue}`);
    } catch (_) {
      return null;
    }
  }
}
