import { Controller } from "@hotwired/stimulus";

// Flags unsaved edits: shows the notice and discard button and marks changed fields until the form is saved or reset.
export default class extends Controller {
  static targets = ["notice", "discard"];

  connect() {
    this.refresh();
  }

  refresh({ type } = {}) {
    if (type === "reset") return setTimeout(() => this.refresh());

    let dirty = false;
    for (const field of this.element.elements) {
      const changed = this.#changed(field);
      field.toggleAttribute("data-dirty", changed && field.type !== "radio" && field.type !== "checkbox");
      dirty ||= changed;
    }

    this.noticeTarget.hidden = !dirty;
    this.discardTarget.hidden = !dirty;
  }

  #changed(field) {
    if (!field.name || field.type === "hidden" || field.type === "submit" || field.type === "reset") return false;
    if (field.type === "radio" || field.type === "checkbox") return field.checked !== field.defaultChecked;

    return field.value !== field.defaultValue;
  }
}
