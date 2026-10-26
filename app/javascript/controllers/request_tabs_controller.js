import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.scrollIntoView({ inline: "nearest", block: "nearest" });
  }
}
