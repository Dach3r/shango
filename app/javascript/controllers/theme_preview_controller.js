import { Controller } from "@hotwired/stimulus";

// Previews the selected color scheme or palette on the page and saves it right away.
// Omarchy palettes pin their own color scheme, so the scheme picker is disabled while one is selected.
export default class extends Controller {
  static targets = ["schemes"];

  apply({ target: { name, value, dataset } }) {
    if (name.endsWith("[color_scheme]")) {
      document.documentElement.dataset.theme = value;
    } else if (name.endsWith("[theme]")) {
      document.documentElement.dataset.palette = value;
      this.pin(dataset.scheme);
    }

    this.element.requestSubmit();
  }

  pin(scheme) {
    const inputs = this.schemesTarget.querySelectorAll("input");

    inputs.forEach((input) => (input.disabled = Boolean(scheme)));
    document.documentElement.dataset.theme = scheme || this.schemesTarget.querySelector("input:checked").value;
  }
}
