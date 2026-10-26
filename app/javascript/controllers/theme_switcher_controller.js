import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  apply({ params: { theme } }) {
    document.documentElement.dataset.theme = theme;
  }
}
