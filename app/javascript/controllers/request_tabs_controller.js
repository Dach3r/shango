import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  connect() {
    this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.scrollIntoView({ inline: "nearest", block: "nearest" });
  }

  // Browsers reserve Cmd/Ctrl+W, so the shortcut is Option/Alt+W.
  closeCurrent(event) {
    if (event.code !== "KeyW" || !event.altKey || event.shiftKey || event.metaKey || event.ctrlKey) return;

    const close = this.element
      .querySelector("[aria-current=page]")
      ?.closest("[data-request-tab]")
      ?.querySelector("[data-request-tab-close]");
    if (!close) return;

    event.preventDefault();
    close.click();
  }

  closeTab(event) {
    event.currentTarget
      .closest("[data-request-tab]")
      .querySelector("[data-request-tab-close]")
      .click();
  }

  // Asks once per tab that holds edits; the ones the user keeps are sent along so the server leaves them open.
  async confirmClose(event) {
    const form = event.currentTarget;
    if (form.dataset.confirmed) return;

    event.preventDefault();
    for (const tab of this.closingTabs(form)) {
      const { confirmMessage, confirmLabel, requestTabId } = tab.dataset;
      if (tab.dataset.dirty === undefined) continue;
      if (await Turbo.config.forms.confirm(confirmMessage, form, undefined, confirmLabel)) continue;
      if (form.dataset.requestTabsSide === "self") return;

      const keep = document.createElement("input");
      Object.assign(keep, { type: "hidden", name: "keep[]", value: requestTabId });
      form.append(keep);
    }
    form.dataset.confirmed = true;
    form.requestSubmit();
  }

  closingTabs(form) {
    const tabs = [...this.element.querySelectorAll("[data-request-tab]")];
    const side = form.dataset.requestTabsSide;
    if (side === "all") return tabs;
    if (side === "self") return [form.closest("[data-request-tab]")];

    const pivot = tabs.indexOf(form.closest("[data-request-tab]"));
    return side === "left" ? tabs.slice(0, pivot) : tabs.slice(pivot + 1);
  }
}
