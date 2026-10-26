import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  apply({ target }) {
    document.documentElement.dataset.zoom = target.value;
    this.element.requestSubmit();
  }
}
