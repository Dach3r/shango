import { Controller } from "@hotwired/stimulus";

// The ports field is a hidden input fed by a preset select. The "custom" preset reveals a text input inside the select panel;
// typing there updates the field and labels the custom option with the typed list.
export default class extends Controller {
  static targets = ["field", "preset", "custom", "customWrap"];
  static values = { customLabel: String };

  connect() {
    this.previous = this.presetTarget.value;
    this.sync();
  }

  apply() {
    const chosen = this.presetTarget.value;
    const cleared = chosen === "custom" && this.previous !== "custom";

    this.previous = chosen;
    if (chosen !== "custom") this.fieldTarget.value = chosen;
    if (cleared) this.clear();
    this.sync();
    if (this.presetTarget.value === "custom") this.customTarget.focus();
  }

  clear() {
    this.fieldTarget.value = "";
    this.customOption.dataset.label = this.customLabelValue;
    this.customOption.firstElementChild.textContent = this.customLabelValue;
    this.presetTarget.dispatchEvent(new Event("change"));
  }

  typed() {
    const typed = this.customTarget.value.trim();
    this.fieldTarget.value = typed;
    this.customOption.dataset.label = typed || this.customLabelValue;
    this.customOption.firstElementChild.textContent = this.customOption.dataset.label;
    this.presetTarget.value = "custom";
    this.previous = "custom";
    this.presetTarget.dispatchEvent(new Event("change"));
  }

  sync() {
    const custom = this.presetTarget.value === "custom";
    this.customWrapTarget.hidden = !custom;
    if (custom && this.customTarget.value !== this.fieldTarget.value) this.customTarget.value = this.fieldTarget.value;
  }

  get customOption() {
    return this.element.querySelector("[data-select-target='option'][data-value='custom']");
  }
}
