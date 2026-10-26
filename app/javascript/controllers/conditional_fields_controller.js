import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["field"];

  connect() {
    this.update();
  }

  update() {
    const inactiveSection = this.element.closest(
      "[data-auth-form-target='section']",
    )?.hidden;

    this.fieldTargets.forEach((wrapper) => {
      const conditions = JSON.parse(wrapper.dataset.showWhen || "{}");
      const visible = Object.entries(conditions).every(([name, values]) =>
        values.includes(this.valueOf(name)),
      );
      wrapper.hidden = !visible;
      wrapper.querySelectorAll("input, textarea, select").forEach((field) => {
        field.disabled = !visible || inactiveSection;
      });
    });
  }

  valueOf(name) {
    return this.element.querySelector(`[data-field-name='${name}']`)?.value;
  }
}
