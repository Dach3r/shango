import { Controller } from "@hotwired/stimulus";

// Saves the settings of a stored request as soon as one changes, without the save button.
export default class extends Controller {
  static values = { url: String };

  save() {
    const body = new FormData();
    this.element.querySelectorAll("input[name]:not(:disabled)").forEach((field) => {
      if (field.type === "checkbox" && !field.checked) return;
      body.append(field.name, field.value);
    });

    fetch(this.urlValue, {
      method: "PATCH",
      body,
      headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
      credentials: "same-origin",
    }).catch(() => {});
  }
}
