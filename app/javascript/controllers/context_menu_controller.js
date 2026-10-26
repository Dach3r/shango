import { Controller } from "@hotwired/stimulus";

const MENU_WIDTH_REM = 13.5;

// Right click opens the row's actions menu at the pointer; the "…" button keeps working as usual.
export default class extends Controller {
  open(event) {
    if (event.target.closest("input, [data-dropdown-target='menu']")) return;

    const menu = this.menu;
    if (!menu) return;

    event.preventDefault();
    event.stopPropagation();
    this.dropdowns.forEach((dropdown) => dropdown.close());
    this.dropdown.open();
    const menuWidth =
      MENU_WIDTH_REM * parseFloat(getComputedStyle(document.documentElement).fontSize);
    Object.assign(menu.style, {
      position: "fixed",
      top: `${event.clientY}px`,
      left: `${Math.min(event.clientX, window.innerWidth - menuWidth)}px`,
      right: "auto",
      marginTop: "0",
    });
  }

  rename() {
    const target = this.element.querySelector(
      "[data-controller~='inline-rename']",
    );
    this.application
      .getControllerForElementAndIdentifier(target, "inline-rename")
      .begin();
  }

  get menu() {
    return this.element.querySelector(
      ":scope > .absolute [data-dropdown-target='menu']",
    );
  }

  get dropdown() {
    return this.dropdownFor(this.menu.closest("[data-controller~='dropdown']"));
  }

  get dropdowns() {
    return [
      ...document.querySelectorAll(
        "[data-dropdown-target='menu']:not([hidden])",
      ),
    ].map((menu) => this.dropdownFor(menu.closest("[data-controller~='dropdown']")));
  }

  dropdownFor(element) {
    return this.application.getControllerForElementAndIdentifier(
      element,
      "dropdown",
    );
  }
}
