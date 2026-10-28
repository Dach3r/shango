import { Controller } from "@hotwired/stimulus";

const PATTERN = /\{\{\s*([^{}\s]+)\s*\}\}/g;

// Fills the `[data-url-preview-slot]` elements (the response toolbar) with the URL with the {{variables}} of the selected environment replaced (secrets stay masked).
export default class extends Controller {
  static values = { variables: { type: Array, default: [] } };

  connect() {
    this.update();
  }

  update() {
    const form = this.element;
    const url = form.querySelector("[name='api_request[url]']");

    for (const slot of document.querySelectorAll("[data-url-preview-slot]")) {
      slot.replaceChildren(...this.segments(url?.value ?? ""));
    }
  }

  variableSaved({ detail: { url, set, value } }) {
    this.variablesValue = this.variablesValue.map((item) =>
      item.url === url ? { ...item, set, value } : item,
    );
  }

  variableCreated({ detail }) {
    if (this.variablesValue.some((item) => item.name === detail.name)) return;

    this.variablesValue = [...this.variablesValue, detail];
  }

  variablesValueChanged() {
    this.update();
  }

  segments(text) {
    const nodes = [];
    let last = 0;

    for (const match of text.matchAll(PATTERN)) {
      if (match.index > last) nodes.push(text.slice(last, match.index));

      const variable = this.variablesValue.find((item) => item.name === match[1]);
      const node = document.createElement("span");
      node.textContent = variable ? variable.value : match[0];
      if (!variable) node.className = "text-danger";
      nodes.push(node);
      last = match.index + match[0].length;
    }

    if (last < text.length) nodes.push(text.slice(last));
    return nodes;
  }
}
