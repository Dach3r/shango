import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "section"];

  connect() {
    this.render();
  }

  change() {
    this.render();
  }

  render() {
    const type = this.selectTarget.value;

    this.sectionTargets.forEach((section) => {
      const active = section.dataset.type === type;
      section.hidden = !active;
      section.querySelectorAll("input, textarea, select").forEach((field) => {
        field.disabled = !active;
      });
      section
        .querySelector("[data-controller~='conditional-fields']")
        ?.dispatchEvent(new CustomEvent("refresh"));
    });
  }
}
