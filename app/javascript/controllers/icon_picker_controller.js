import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["query", "option", "empty", "grid"];

  filter() {
    const query = this.queryTarget.value
      .trim()
      .toLowerCase()
      .replace(/\s+/g, "-");
    let visible = 0;

    this.optionTargets.forEach((option) => {
      const match = option.dataset.name.includes(query);
      option.classList.toggle("hidden", !match);
      if (match) visible++;
    });

    this.emptyTarget.classList.toggle("hidden", visible > 0);
    this.gridTarget.scrollTop = 0;
  }

  // Enter in the search box must not submit the form.
  preventSubmit(event) {
    event.preventDefault();
  }
}
