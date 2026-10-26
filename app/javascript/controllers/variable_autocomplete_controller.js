import { Controller } from "@hotwired/stimulus";

import { DYNAMIC_VARIABLES, completions, referenceStatus } from "lib/response_reference";

const TRIGGER = /\{\{[^{}\s]*$/;
const REFERENCE = /\{\{\s*([^{}\s]+)\s*\}\}/g;
const MIRRORED_STYLES = [
  "fontFamily", "fontSize", "fontWeight", "fontStyle", "letterSpacing", "lineHeight", "textAlign", "textIndent",
  "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
  "borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth",
];
const FIELDS = "input, textarea";
const SKIPPED_TYPES = ["hidden", "checkbox", "radio", "file", "number", "range"];

// Offers `{{variable}}` completion on the plain inputs inside this element (code editors bring their own)
// and highlights the references by state, like the code editor does, with a mirror layer over the field.
export default class extends Controller {
  static values = {
    variables: { type: Array, default: [] },
    responses: { type: Array, default: [] },
    labels: { type: Object, default: {} },
  };

  connect() {
    this.onInput = (event) => this.update(event.target);
    this.onKeydown = (event) => this.keydown(event);
    this.onFocusOut = () => this.close();
    this.onRefresh = (event) => this.highlight(event.target);
    this.onRelayout = (event) => {
      if (this.supported(event.target)) this.highlight(event.target);
    };
    this.mirrors = new Map();
    this.observer = new MutationObserver((records) => {
      if (records.some((record) => !this.insideMirror(record.target))) this.highlightAll();
    });
    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["hidden"],
    });
    window.addEventListener("resize", this.highlightAll);
    this.element.addEventListener("input", this.onRefresh);
    this.element.addEventListener("keyup", this.onRelayout);
    this.element.addEventListener("click", this.onRelayout);
    this.element.addEventListener("focusin", this.onRelayout);
    this.element.addEventListener("variable-autocomplete:refresh", this.onRefresh);
    this.element.addEventListener("scroll", this.onRelayout, true);
    this.element.addEventListener("input", this.onInput);
    this.element.addEventListener("keydown", this.onKeydown, true);
    this.element.addEventListener("focusout", this.onFocusOut);
    this.highlightAll();
  }

  disconnect() {
    this.observer.disconnect();
    window.removeEventListener("resize", this.highlightAll);
    this.element.removeEventListener("input", this.onRefresh);
    this.element.removeEventListener("keyup", this.onRelayout);
    this.element.removeEventListener("click", this.onRelayout);
    this.element.removeEventListener("focusin", this.onRelayout);
    this.element.removeEventListener("variable-autocomplete:refresh", this.onRefresh);
    this.element.removeEventListener("scroll", this.onRelayout, true);
    this.mirrors.forEach((mirror) => mirror.remove());
    this.mirrors.clear();
    this.element.removeEventListener("input", this.onInput);
    this.element.removeEventListener("keydown", this.onKeydown, true);
    this.element.removeEventListener("focusout", this.onFocusOut);
    this.close();
  }

  supported(field) {
    return (
      field.matches?.(FIELDS) &&
      !SKIPPED_TYPES.includes(field.type) &&
      !field.closest("[data-controller~='code-editor'], [data-controller~='select']")
    );
  }

  insideMirror(node) {
    const element = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
    return Boolean(element?.closest("[data-variable-mirror]"));
  }

  highlightAll = () => {
    this.mirrors.forEach((mirror, field) => {
      if (!field.isConnected) {
        mirror.remove();
        this.mirrors.delete(field);
      }
    });
    this.element.querySelectorAll(FIELDS).forEach((field) => {
      if (this.supported(field)) this.highlight(field);
    });
  };

  status(name) {
    if (name in DYNAMIC_VARIABLES) return "dynamic";
    if (name.startsWith("response.")) return referenceStatus(name, this.responsesValue);

    const variable = this.variablesValue.find((item) => item.name === name);
    if (!variable) return "missing";

    return variable.set ? "set" : "empty";
  }

  // Paints `{{variable}}` references over a field whose own text turns transparent; masked fields show as text while they hold one.
  highlight(field) {
    if (!this.supported(field)) return;

    const referenced = field.value.includes("{{");
    if (field.dataset.masked === undefined && field.type === "password") field.dataset.masked = "";
    if (field.dataset.masked !== undefined) field.type = referenced ? "text" : "password";

    let mirror = this.mirrors.get(field);
    const active = referenced && field.offsetParent !== null && field.value.match(REFERENCE);
    if (!active) {
      if (mirror) mirror.hidden = true;
      field.style.color = "";
      field.style.caretColor = "";
      return;
    }

    if (!mirror) {
      mirror = document.createElement("div");
      mirror.setAttribute("aria-hidden", "true");
      mirror.dataset.variableMirror = "";
      mirror.append(document.createElement("div"));
      field.before(mirror);
      this.mirrors.set(field, mirror);
    }

    const styles = getComputedStyle(field);
    const color = field.style.color === "transparent" ? mirror.style.color : styles.color;
    const multiline = field.tagName === "TEXTAREA";
    const style = mirror.style;
    MIRRORED_STYLES.forEach((property) => (style[property] = styles[property]));
    Object.assign(style, {
      position: "absolute",
      left: `${field.offsetLeft}px`,
      top: `${field.offsetTop}px`,
      width: `${field.offsetWidth}px`,
      height: `${field.offsetHeight}px`,
      margin: "0",
      borderStyle: "solid",
      borderColor: "transparent",
      boxSizing: "border-box",
      overflow: "hidden",
      pointerEvents: "none",
      color,
      whiteSpace: multiline ? "pre-wrap" : "pre",
      overflowWrap: multiline ? "break-word" : "normal",
    });
    mirror.hidden = false;
    field.style.color = "transparent";
    field.style.caretColor = color;

    const content = mirror.firstChild;
    content.style.transform = `translate(${-field.scrollLeft}px, ${-field.scrollTop}px)`;
    content.replaceChildren(...this.segments(field.value));
  }

  segments(text) {
    const nodes = [];
    let last = 0;
    for (const match of text.matchAll(REFERENCE)) {
      nodes.push(document.createTextNode(text.slice(last, match.index)));
      const mark = document.createElement("span");
      mark.className = `cm-var cm-var-${this.status(match[1])}`;
      mark.textContent = match[0];
      nodes.push(mark);
      last = match.index + match[0].length;
    }
    nodes.push(document.createTextNode(text.slice(last)));
    return nodes;
  }

  update(field) {
    if (!this.supported(field)) return;

    const caret = field.selectionStart ?? field.value.length;
    const match = field.value.slice(0, caret).match(TRIGGER);
    if (!match) return this.close();

    const typed = match[0].slice(2);
    const { offset, options } = completions(typed, {
      variables: this.variablesValue,
      responses: this.responsesValue,
      labels: this.labelsValue,
    });
    const query = typed.slice(offset).toLowerCase();
    const matches = options.filter(({ label }) => label.toLowerCase().includes(query));
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
    name.textContent = option.label;
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
    const closed = field.value.slice(to, to + 2) === "}}";
    const closing = option.complete && !closed ? "}}" : "";
    const insert = `${option.insert}${closing}`;

    field.setRangeText(insert, from, to, "end");
    if (option.complete && closed) field.setSelectionRange(from + insert.length + 2, from + insert.length + 2);
    this.close();
    field.dispatchEvent(new Event("input", { bubbles: true }));
  }

  close() {
    this.popup?.remove();
    this.popup = null;
    this.field = null;
  }
}
