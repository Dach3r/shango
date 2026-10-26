import { Controller } from "@hotwired/stimulus";

// Previews the selected color scheme or palette on the page before saving.
export default class extends Controller {
  apply({ target: { name, value } }) {
    if (name.endsWith("[color_scheme]")) {
      document.documentElement.dataset.theme = value;
    } else if (name.endsWith("[theme]")) {
      document.documentElement.dataset.palette = value;
    }
  }
}
