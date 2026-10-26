import { Controller } from "@hotwired/stimulus";

const DYNAMIC_VARIABLES = {
  $guid: "guid",
  $isoTimestamp: "isoTimestamp",
  $randomInt: "randomInt",
  $timestamp: "timestamp",
};
const TRIGGER = /\{\{[\w.\-$]*$/;
const FIELDS = "input, textarea";
const SKIPPED_TYPES = ["hidden", "checkbox", "radio", "file", "number", "range"];

// Offers `{{variable}}` completion on the plain inputs inside this element (code editors bring their own).
export default class extends Controller {
  static values = {
    variables: { type: Array, default: [] },
    labels: { type: Object, default: {} },
  };

  connect() {
    this.onInput = (event) => this.update(event.target);
    this.onKeydown = (event) => this.keydown(event);
    this.onFocusOut = () => this.close();
    this.element.addEventListener("input", this.onInput);
    this.element.addEventListener("keydown", this.onKeydown, true);
    this.element.addEventListener("focusout", this.onFocusOut);
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInput);
    this.element.removeEventListener("keydown", this.onKeydown, true);
    this.element.removeEventListener("focusout", this.onFocusOut);
    this.close();
  }

  supported(field) {
    return (
      field.matches?.(FIELDS) &&
      !SKIPPED_TYPES.includes(field.type) &&
      !field.closest("[data-controller~='code-editor']")
    );
  }

  options() {
    const labels = this.labelsValue;
    return [
      ...this.variablesValue.map(({ name, set, value }) => ({
        name,
        status: set ? "set" : "empty",
        info: set ? "" : labels.empty,
        value,
        section: labels.environment,
      })),
      ...Object.entries(DYNAMIC_VARIABLES).map(([name, key]) => ({
        name,
        status: "dynamic",
        info: labels[key],
        section: labels.dynamic,
      })),
    ];
  }

  update(field) {
    if (!this.supported(field)) return;

    const caret = field.selectionStart ?? field.value.length;
    const match = field.value.slice(0, caret).match(TRIGGER);
    if (!match) return this.close();

    const query = match[0].slice(2).toLowerCase();
    const matches = this.options().filter(({ name }) =>
      name.toLowerCase().includes(query),
    );
    if (matches.length === 0) return this.close();

    this.field = field;
    this.range = [caret - query.length, caret];
    this.matches = matches;
    this.selected = 0;
    this.render();
  }

  render() {
    if (!this.popup) {
      this.popup = document.createElement("ul");
      this.popup.setAttribute("role", "listbox");
      this.popup.className =
        "fixed z-[100] max-h-64 min-w-64 max-w-md overflow-auto rounded-xl border border-line bg-card p-1 font-mono text-xs text-body shadow-[var(--dropdown-shadow)]";
      this.popup.addEventListener("mousedown", (event) => event.preventDefault());
      document.body.append(this.popup);
    }

    const rect = this.field.getBoundingClientRect();
    this.popup.style.left = `${rect.left}px`;
    this.popup.style.top = `${rect.bottom + 4}px`;
    this.popup.replaceChildren(
      ...this.matches.map((option, index) => this.item(option, index)),
    );
    this.popup.children[this.selected]?.scrollIntoView({ block: "nearest" });
  }

  item(option, index) {
    const item = document.createElement("li");
    item.setAttribute("role", "option");
    item.className = `cursor-pointer rounded-lg px-2 py-1.5 ${index === this.selected ? "bg-field text-ink" : ""}`;

    const row = document.createElement("div");
    row.className = "flex items-center";
    const dot = document.createElement("span");
    dot.className = `cm-var-dot cm-var-dot-${option.status}`;
    const name = document.createElement("span");
    name.className = "flex-1 truncate";
    name.textContent = option.name;
    const info = document.createElement("span");
    info.className = "ml-6 font-sans text-[11px] text-muted";
    info.textContent = option.info;
    row.append(dot, name, info);
    item.append(row);

    if (option.value) {
      const value = document.createElement("div");
      value.className = "ml-3.5 truncate text-[11px] text-muted";
      value.textContent = option.value;
      item.append(value);
    }

    item.addEventListener("mousedown", (event) => {
      event.preventDefault();
      this.accept(index);
    });
    return item;
  }

  keydown(event) {
    if (!this.popup) return;

    switch (event.key) {
      case "ArrowDown":
        this.move(1);
        break;
      case "ArrowUp":
        this.move(-1);
        break;
      case "Enter":
      case "Tab":
        this.accept(this.selected);
        break;
      case "Escape":
        this.close();
        break;
      default:
        return;
    }
    event.preventDefault();
    event.stopPropagation();
  }

  move(step) {
    const size = this.matches.length;
    this.selected = (this.selected + step + size) % size;
    this.render();
  }

  accept(index) {
    const option = this.matches[index];
    const field = this.field;
    const [from, to] = this.range;
    const closing = field.value.slice(to, to + 2) === "}}" ? "" : "}}";
    const insert = `${option.name}${closing}`;

    field.setRangeText(insert, from, to, "end");
    if (closing === "") field.setSelectionRange(from + insert.length + 2, from + insert.length + 2);
    this.close();
    field.dispatchEvent(new Event("input", { bubbles: true }));
  }

  close() {
    this.popup?.remove();
    this.popup = null;
    this.field = null;
  }
}
