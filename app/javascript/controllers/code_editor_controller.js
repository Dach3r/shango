import { Controller } from "@hotwired/stimulus";

const DYNAMIC_VARIABLES = {
  $guid: "guid",
  $isoTimestamp: "isoTimestamp",
  $randomInt: "randomInt",
  $timestamp: "timestamp",
};

export default class extends Controller {
  static targets = ["input", "mount"];
  static values = {
    language: { type: String, default: "text" },
    readonly: Boolean,
    singleLine: Boolean,
    placeholder: String,
    variables: { type: Array, default: [] },
    labels: { type: Object, default: {} },
    wrap: { type: Boolean, default: true },
  };

  async connect() {
    const token = (this.token = Symbol("connect"));
    const cm = await import("codemirror");
    if (this.token !== token) return;

    this.cm = cm;
    this.languageCompartment = new cm.Compartment();
    this.variablesCompartment = new cm.Compartment();
    this.mountTarget.replaceChildren();
    this.view = new cm.EditorView({
      parent: this.mountTarget,
      state: cm.EditorState.create({
        doc: this.inputTarget.value,
        extensions: this.extensions(),
      }),
    });
    this.element.dataset.ready = "true";
  }

  disconnect() {
    this.token = null;
    this.view?.destroy();
    this.view = null;
    delete this.element.dataset.ready;
  }

  languageValueChanged() {
    if (!this.view) return;

    this.view.dispatch({
      effects: this.languageCompartment.reconfigure(this.languageExtension()),
    });
  }

  // Replaces the whole document (used by the URL/params sync and the pretty/raw toggle).
  setValue(text) {
    if (!this.view) {
      this.inputTarget.value = text;
      return;
    }
    if (this.view.state.doc.toString() === text) return;

    this.view.dispatch({
      changes: { from: 0, to: this.view.state.doc.length, insert: text },
    });
  }

  // Another editor saved a variable: keep this one's highlighting and hover cards in sync.
  variableSaved({ detail: { url, set, value } }) {
    this.variablesValue = this.variablesValue.map((item) =>
      item.url === url ? { ...item, set, value } : item,
    );
    this.view?.dispatch({
      effects: this.variablesCompartment.reconfigure(this.variableDecorations()),
    });
  }

  changeLanguage(event) {
    this.languageValue = event.detail.language;
  }

  extensions() {
    const cm = this.cm;
    const list = [
      cm.history(),
      cm.drawSelection(),
      cm.syntaxHighlighting(this.highlightStyle()),
      cm.EditorView.theme(this.theme()),
      this.languageCompartment.of(this.languageExtension()),
      this.variablesCompartment.of(this.variableDecorations()),
      this.variableHover(),
      cm.keymap.of([
        ...cm.defaultKeymap.filter((binding) => binding.key !== "Mod-Enter"),
        ...cm.historyKeymap,
        ...cm.searchKeymap,
        ...cm.foldKeymap,
        ...cm.completionKeymap,
      ]),
      cm.EditorView.updateListener.of((update) => this.changed(update)),
    ];

    if (this.placeholderValue) list.push(cm.placeholder(this.placeholderValue));
    if (this.wrapValue || this.singleLineValue)
      list.push(cm.EditorView.lineWrapping);
    if (this.readonlyValue)
      list.push(
        cm.EditorState.readOnly.of(true),
        cm.EditorView.editable.of(false),
      );

    if (this.singleLineValue) {
      list.push(
        cm.EditorState.transactionFilter.of((transaction) =>
          transaction.newDoc.lines > 1 ? [] : transaction,
        ),
      );
    } else {
      list.push(
        cm.lineNumbers(),
        cm.foldGutter(),
        cm.highlightActiveLine(),
        cm.bracketMatching(),
        cm.search({ top: true }),
      );
      if (!this.readonlyValue)
        list.push(cm.closeBrackets(), cm.keymap.of(cm.closeBracketsKeymap));
    }

    if (!this.readonlyValue) {
      list.push(
        cm.autocompletion({
          override: [(context) => this.completeVariables(context)],
          icons: false,
          addToOptions: [
            {
              render: (completion) => {
                const dot = document.createElement("span");
                dot.className = `cm-var-dot cm-var-dot-${completion.type}`;
                return dot;
              },
              position: 10,
            },
            {
              render: (completion) => {
                if (!completion.value) return null;

                const value = document.createElement("div");
                value.className = "cm-var-value";
                value.textContent = completion.value;
                return value;
              },
              position: 90,
            },
          ],
          optionClass: () => "cm-var-option",
        }),
      );
    }

    return list;
  }

  languageExtension() {
    const cm = this.cm;
    switch (this.languageValue) {
      case "json":
        return cm.json();
      case "xml":
        return cm.xml();
      case "html":
        return cm.html();
      case "javascript":
        return cm.javascript();
      default:
        return [];
    }
  }

  // Highlights {{variable}} references by state; the styles live in application.css (.cm-var-*).
  variableStatus(name) {
    if (name in DYNAMIC_VARIABLES) return "dynamic";

    const variable = this.variablesValue.find((item) => item.name === name);
    if (!variable) return "missing";

    return variable.set ? "set" : "empty";
  }

  variableDecorations() {
    const cm = this.cm;
    const decorator = new cm.MatchDecorator({
      regexp: /\{\{\s*([^{}\s]+)\s*\}\}/g,
      decoration: (match) =>
        cm.Decoration.mark({
          class: `cm-var cm-var-${this.variableStatus(match[1])}`,
        }),
    });

    return cm.ViewPlugin.fromClass(
      class {
        constructor(view) {
          this.decorations = decorator.createDeco(view);
        }
        update(update) {
          this.decorations = decorator.updateDeco(update, this.decorations);
        }
      },
      { decorations: (plugin) => plugin.decorations },
    );
  }

  // Shows the variable's source and value (secrets arrive masked) while hovering a {{variable}}.
  variableHover() {
    const regexp = /\{\{\s*([^{}\s]+)\s*\}\}/g;
    return this.cm.hoverTooltip((view, pos) => {
      const line = view.state.doc.lineAt(pos);
      for (const match of line.text.matchAll(regexp)) {
        const from = line.from + match.index;
        const to = from + match[0].length;
        if (pos < from || pos > to) continue;

        return {
          pos: from,
          end: to,
          above: true,
          create: () => this.variableCard(match[1]),
        };
      }
      return null;
    });
  }

  variableCard(name) {
    const labels = this.labelsValue;
    const status = this.variableStatus(name);
    const variable = this.variablesValue.find((item) => item.name === name);
    const card = document.createElement("div");
    card.className = "cm-var-card";

    const value =
      status === "set" || status === "empty"
        ? this.variableInput(variable)
        : document.createElement("div");
    if (value.tagName === "DIV") {
      value.className = `cm-var-card-value cm-var-card-${status}`;
      value.textContent =
        status === "dynamic" ? labels[DYNAMIC_VARIABLES[name]] : labels.missing;
    }

    const source = document.createElement("div");
    source.className = "cm-var-card-source";
    source.textContent =
      status === "dynamic" ? labels.dynamic : labels.environment;

    card.append(value, source);
    return { dom: card, destroy: () => value.flush?.() };
  }

  // Edits the variable in place. Secrets arrive masked, so their input starts empty and a blank save keeps the stored value.
  variableInput(variable) {
    const input = document.createElement("input");
    input.className = "cm-var-card-value cm-var-card-input";
    input.value = variable.secret ? "" : variable.value;
    input.placeholder = variable.secret && variable.set ? variable.value : this.labelsValue.empty;
    input.autocomplete = "off";
    input.spellcheck = false;

    let saved = input.value;
    let timer = null;
    input.flush = () => {
      clearTimeout(timer);
      if (input.value !== saved) this.saveVariable(variable, (saved = input.value));
    };
    input.addEventListener("input", () => {
      clearTimeout(timer);
      timer = setTimeout(input.flush, 600);
    });
    input.addEventListener("change", input.flush);
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") input.flush();
      if (event.key === "Escape") this.view.focus();
    });
    return input;
  }

  async saveVariable(variable, value) {
    const response = await fetch(variable.url, {
      method: "PATCH",
      body: new URLSearchParams({ "variable[value]": value }),
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          ?.content,
      },
      credentials: "same-origin",
    });
    if (!response.ok) return;

    const { set, value: shown } = await response.json();
    window.dispatchEvent(
      new CustomEvent("variable:saved", {
        detail: { url: variable.url, set, value: shown },
      }),
    );
  }

  completeVariables(context) {
    const match = context.matchBefore(/\{\{[\w.\-$]*/);
    if (!match) return null;

    const labels = this.labelsValue;
    const environment = { name: labels.environment, rank: 0 };
    const dynamic = { name: labels.dynamic, rank: 1 };
    const options = [
      ...this.variablesValue.map(({ name, set, value }) => ({
        name,
        status: set ? "set" : "empty",
        info: set ? null : labels.empty,
        value,
        section: environment,
      })),
      ...Object.entries(DYNAMIC_VARIABLES).map(([name, key]) => ({
        name,
        status: "dynamic",
        info: labels[key],
        section: dynamic,
      })),
    ];
    const closing =
      context.state.sliceDoc(context.pos, context.pos + 2) === "}}" ? "" : "}}";
    return {
      from: match.from + 2,
      options: options.map(({ name, status, info, value, section }) => ({
        label: name,
        apply: `${name}${closing}`,
        type: status,
        detail: info,
        value,
        section,
      })),
      validFor: /^[\w.\-$]*$/,
    };
  }

  changed(update) {
    if (!update.docChanged) return;

    this.inputTarget.value = update.state.doc.toString();
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }));
  }

  highlightStyle() {
    const { HighlightStyle, tags: t } = this.cm;
    return HighlightStyle.define([
      { tag: [t.propertyName, t.attributeName], color: "var(--syn-key)" },
      { tag: [t.string, t.special(t.string)], color: "var(--syn-string)" },
      { tag: [t.number, t.bool, t.null], color: "var(--syn-number)" },
      {
        tag: [t.keyword, t.tagName, t.operatorKeyword],
        color: "var(--syn-keyword)",
      },
      {
        tag: [t.comment, t.meta],
        color: "var(--syn-comment)",
        fontStyle: "italic",
      },
      {
        tag: [t.punctuation, t.bracket, t.angleBracket],
        color: "var(--muted)",
      },
    ]);
  }

  theme() {
    const singleLine = this.singleLineValue;
    return {
      "&": {
        color: "var(--ink)",
        backgroundColor: "transparent",
        fontSize: "13px",
        height: singleLine ? "auto" : "100%",
      },
      "&.cm-focused": { outline: "none" },
      ".cm-scroller": {
        fontFamily: "var(--font-mono)",
        lineHeight: "1.6",
        overflow: "auto",
      },
      ".cm-content": {
        caretColor: "var(--ink)",
        padding: singleLine ? "0" : "8px 0",
      },
      ".cm-cursor": { borderLeftColor: "var(--ink)" },
      ".cm-gutters": {
        backgroundColor: "transparent",
        color: "var(--faint)",
        border: "none",
      },
      ".cm-activeLine": {
        backgroundColor: "color-mix(in oklab, var(--ink) 4%, transparent)",
      },
      ".cm-activeLineGutter": {
        backgroundColor: "transparent",
        color: "var(--muted)",
      },
      "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection":
        {
          backgroundColor:
            "color-mix(in oklab, var(--accent) 25%, transparent)",
        },
      ".cm-tooltip": {
        backgroundColor: "var(--card)",
        border: "1px solid var(--line)",
        borderRadius: "10px",
        boxShadow: "var(--dropdown-shadow)",
        color: "var(--body)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete": {
        padding: "4px",
        minWidth: "260px",
        maxWidth: "420px",
        fontFamily: "var(--font-sans)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul": {
        fontFamily: "var(--font-mono)",
        fontSize: "12.5px",
        maxHeight: "260px",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > completion-section": {
        display: "block",
        padding: "8px 8px 4px",
        border: "none",
        color: "var(--muted)",
        fontFamily: "var(--font-sans)",
        fontSize: "10.5px",
        fontWeight: "600",
        letterSpacing: "0.06em",
        textTransform: "uppercase",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li": {
        display: "flex",
        flexWrap: "wrap",
        alignItems: "center",
        padding: "5px 8px",
        borderRadius: "8px",
        color: "var(--body)",
        lineHeight: "1.4",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li > .cm-completionLabel": {
        flex: "1",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li > .cm-completionDetail": {
        marginLeft: "24px",
        fontFamily: "var(--font-sans)",
        fontSize: "11px",
        fontStyle: "normal",
        color: "var(--muted)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li > .cm-var-value": {
        flexBasis: "100%",
        overflow: "hidden",
        marginLeft: "14px",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",
        fontSize: "11px",
        color: "var(--muted)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete ul li[aria-selected]": {
        backgroundColor: "var(--field)",
        color: "var(--ink)",
      },
      ".cm-tooltip.cm-tooltip-hover": {
        padding: "10px",
        minWidth: "220px",
        maxWidth: "420px",
      },
      ".cm-var-card": { fontFamily: "var(--font-sans)", fontSize: "12px" },
      ".cm-var-card-value": {
        padding: "8px 10px",
        border: "1px solid var(--line)",
        borderRadius: "8px",
        backgroundColor: "var(--field)",
        color: "var(--ink)",
        fontFamily: "var(--font-mono)",
        wordBreak: "break-all",
      },
      ".cm-var-card-input": {
        display: "block",
        width: "100%",
        outline: "none",
        boxSizing: "border-box",
      },
      ".cm-var-card-input:focus": { borderColor: "var(--accent)" },
      ".cm-var-card-empty, .cm-var-card-missing": {
        color: "var(--muted)",
        fontFamily: "var(--font-sans)",
      },
      ".cm-var-card-missing": { color: "var(--danger)" },
      ".cm-var-card-source": { marginTop: "8px", color: "var(--muted)" },
      ".cm-panels": {
        backgroundColor: "var(--card)",
        color: "var(--body)",
        borderColor: "var(--line)",
      },
      ".cm-searchMatch": {
        backgroundColor: "color-mix(in oklab, var(--accent) 22%, transparent)",
      },
      ".cm-placeholder": { color: "var(--faint)" },
    };
  }
}
