import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "input",
    "trigger",
    "label",
    "menu",
    "search",
    "list",
    "option",
    "empty",
  ];

  connect() {
    this.render();
  }

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close();
  }

  open() {
    this.menuTarget.hidden = false;
    this.triggerTarget.setAttribute("aria-expanded", "true");
    if (this.hasSearchTarget) this.searchTarget.value = "";
    this.filter();
    this.activate(
      this.optionTargets.find(
        (option) => option.getAttribute("aria-selected") === "true",
      ) || this.visibleOptions[0],
    );
    this.hasSearchTarget
      ? this.searchTarget.focus()
      : this.activeOption?.focus();
  }

  openFromKey() {
    if (this.menuTarget.hidden) this.open();
  }

  close() {
    this.menuTarget.hidden = true;
    this.triggerTarget.setAttribute("aria-expanded", "false");
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close();
  }

  closeOnEscape() {
    if (this.menuTarget.hidden) return;

    this.close();
    this.triggerTarget.focus();
  }

  choose(event) {
    const changed = this.inputTarget.value !== event.currentTarget.dataset.value;

    this.inputTarget.value = event.currentTarget.dataset.value;
    this.render();

    this.close();
    this.triggerTarget.focus();
    if (changed)
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }));
  }

  // Shows the option matching the input's value, so the value can be set before the controller connects.
  render() {
    const selected = this.optionTargets.find(
      (option) => option.dataset.value === this.inputTarget.value,
    );
    if (!selected) return;

    this.labelTarget.textContent = selected.dataset.label;
    this.optionTargets.forEach((item) => {
      item.setAttribute("aria-selected", String(item === selected));
      item
        .querySelector("[data-select-target='check']")
        .classList.toggle("invisible", item !== selected);
    });
  }

  filter() {
    const query = this.hasSearchTarget
      ? this.searchTarget.value.trim().toLowerCase()
      : "";

    this.optionTargets.forEach((option) => {
      option.parentElement.hidden = !option.dataset.label
        .toLowerCase()
        .includes(query);
    });
    this.emptyTarget.hidden = this.visibleOptions.length > 0;
    this.activate(this.visibleOptions[0]);
  }

  navigate(event) {
    const options = this.visibleOptions;
    const index = options.indexOf(this.activeOption);

    if (event.key === "ArrowDown")
      this.activate(options[Math.min(index + 1, options.length - 1)]);
    else if (event.key === "ArrowUp")
      this.activate(options[Math.max(index - 1, 0)]);
    else if (event.key === "Enter" && this.activeOption)
      this.activeOption.click();
    else return;

    event.preventDefault();
    if (!this.hasSearchTarget) this.activeOption?.focus();
  }

  activate(option) {
    this.optionTargets.forEach((item) =>
      item.toggleAttribute("data-active", item === option),
    );
    option?.scrollIntoView({ block: "nearest" });
  }

  get visibleOptions() {
    return this.optionTargets.filter((option) => !option.parentElement.hidden);
  }

  get activeOption() {
    return this.optionTargets.find((option) =>
      option.hasAttribute("data-active"),
    );
  }
}
