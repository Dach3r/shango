import { Controller } from "@hotwired/stimulus";

// Filters a list of items by their text as the user types in the search input.
export default class extends Controller {
  static targets = ["input", "item", "empty"];

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase();
    let visible = 0;
    this.itemTargets.forEach((item) => {
      const match = item.textContent.toLowerCase().includes(query);
      item.hidden = !match;
      if (match) visible += 1;
    });
    this.emptyTarget.hidden = visible > 0;
  }
}
