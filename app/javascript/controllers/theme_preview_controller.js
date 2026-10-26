import { Controller } from "@hotwired/stimulus";

// Previews the selected color scheme or palette on the page and saves it right away.
export default class extends Controller {
  apply({ target: { name, value } }) {
    if (name.endsWith("[color_scheme]")) {
      document.documentElement.dataset.theme = value;
    } else if (name.endsWith("[theme]")) {
      document.documentElement.dataset.palette = value;
    }

    this.element.requestSubmit();
  }
}
