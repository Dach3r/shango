import { Controller } from "@hotwired/stimulus";

// Rows of assertions or extractors: the operator list follows the source, and a field the choice does not need is hidden
// and disabled (so it is not posted).
export default class extends Controller {
  static targets = ["body", "template", "row"];
  static values = { kind: String, operators: Object, labels: Object, targeted: Array, expectless: Array };

  add() {
    const html = this.templateTarget.innerHTML.replaceAll(
      "NEW_INDEX",
      `${Date.now()}${Math.floor(Math.random() * 1000)}`,
    );
    this.bodyTarget.insertAdjacentHTML("beforeend", html);
    this.bodyTarget.lastElementChild.querySelector("[data-field='source']")?.focus();
    this.changed();
  }

  remove(event) {
    event.currentTarget.closest("[data-rule-table-target='row']").remove();
    if (this.rowTargets.length === 0) this.add();
    this.changed();
  }

  sourceChanged(event) {
    const row = event.currentTarget.closest("[data-rule-table-target='row']");
    const source = event.currentTarget.value;

    if (this.kindValue === "assertion") this.fillOperators(row, source);
    this.toggle(row, "target", this.targetedValue.includes(source));
    const target = row.querySelector("[data-role='target']");
    target.placeholder = source === "header" ? target.dataset.placeholderHeader : target.dataset.placeholderJson;
    this.syncExpected(row);
    this.changed();
  }

  operatorChanged(event) {
    this.syncExpected(event.currentTarget.closest("[data-rule-table-target='row']"));
    this.changed();
  }

  changed() {
    this.dispatch("change");
  }

  fillOperators(row, source) {
    const select = row.querySelector("[data-field='operator']");
    const options = this.operatorsValue[source] || [];
    select.replaceChildren(
      ...options.map((operator) => new Option(this.labelsValue[operator], operator)),
    );
  }

  syncExpected(row) {
    const operator = row.querySelector("[data-field='operator']");
    if (operator) this.toggle(row, "expected", !this.expectlessValue.includes(operator.value));
  }

  toggle(row, role, visible) {
    const field = row.querySelector(`[data-role='${role}']`);
    if (!field) return;

    field.hidden = !visible;
    field.disabled = !visible;
  }
}
