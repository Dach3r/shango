import { Controller } from "@hotwired/stimulus";

const COOKIE = "sidebar_collapsed";
const ONE_YEAR = 60 * 60 * 24 * 365;

export default class extends Controller {
  static targets = ["toggle"];

  toggle() {
    const collapsed = this.element.dataset.collapsed !== "true";

    this.element.dataset.collapsed = collapsed;
    this.toggleTarget.setAttribute("aria-expanded", String(!collapsed));
    document.cookie = `${COOKIE}=${collapsed}; path=/; max-age=${ONE_YEAR}; samesite=lax`;
  }
}
