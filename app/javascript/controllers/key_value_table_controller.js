import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["body", "template", "row"];

  add() {
    this.insertRow();
    this.bodyTarget.lastElementChild.querySelector("[data-field='key']")?.focus();
  }

  insertRow() {
    const html = this.templateTarget.innerHTML.replaceAll(
      "NEW_INDEX",
      `${Date.now()}${Math.floor(Math.random() * 1000)}`,
    );
    this.bodyTarget.insertAdjacentHTML("beforeend", html);
  }

  remove(event) {
    const row = event.currentTarget.closest(
      "[data-key-value-table-target='row']",
    );
    const destroy = row.querySelector("[data-destroy]");

    if (destroy) {
      destroy.value = "1";
      row.hidden = true;
    } else {
      row.remove();
    }
    this.ensureRow();
    this.changed();
  }

  input() {
    this.changed();
  }

  changed() {
    this.dispatch("change", { detail: { rows: this.rows() } });
  }

  // Multipart rows switch between a text value and a file picker.
  typeChanged(event) {
    const row = event.currentTarget.closest(
      "[data-key-value-table-target='row']",
    );
    const file = event.currentTarget.value === "file";

    row.querySelector("[data-role='text']").hidden = file;
    row.querySelector("[data-role='file']").hidden = !file;
    row.querySelectorAll("[data-role='text'] input").forEach((field) => {
      field.disabled = file;
    });
    row.querySelectorAll("[data-role='file'] input").forEach((field) => {
      field.disabled = !file;
    });
  }

  // Secret rows hide their value while editing.
  syncMask(event) {
    const row = event.currentTarget.closest(
      "[data-key-value-table-target='row']",
    );
    const value = row.querySelector("[data-field='value']");
    if (value) value.type = event.currentTarget.checked ? "password" : "text";
  }

  // Replaces enabled rows with `pairs` ([[key, value]]), keeping disabled rows (used by the URL sync).
  replaceEnabled(pairs) {
    const rows = this.visibleRows();
    const kept = rows.filter((row) => !this.enabled(row) && this.isFilled(row));
    rows.filter((row) => !kept.includes(row)).forEach((row) => row.remove());

    pairs.forEach(([key, value]) => {
      this.insertRow();
      const row = this.bodyTarget.lastElementChild;
      row.querySelector("[data-field='key']").value = key;
      row.querySelector("[data-field='value']").value = value;
      row.querySelectorAll("[data-field]").forEach((field) =>
        field.dispatchEvent(new CustomEvent("variable-autocomplete:refresh", { bubbles: true })),
      );
    });
    kept.forEach((row) => this.bodyTarget.appendChild(row));
    this.ensureRow();
  }

  // Pairs tables always keep one blank row; blank rows are never sent.
  ensureRow() {
    if (this.element.dataset.alwaysRow === "true" && this.visibleRows().length === 0) this.insertRow();
  }

  rows() {
    return this.visibleRows()
      .map((row) => ({
        key: row.querySelector("[data-field='key']")?.value ?? "",
        value: row.querySelector("[data-field='value']")?.value ?? "",
        enabled: this.enabled(row),
      }))
      .filter((row) => row.key !== "" || row.value !== "");
  }

  visibleRows() {
    return this.rowTargets.filter((row) => !row.hidden);
  }

  enabled(row) {
    const toggle = row.querySelector("[data-field='enabled'][type='checkbox']");
    return toggle ? toggle.checked : true;
  }

  isFilled(row) {
    return [
      ...row.querySelectorAll("[data-field='key'], [data-field='value']"),
    ].some((field) => field.value !== "");
  }
}
