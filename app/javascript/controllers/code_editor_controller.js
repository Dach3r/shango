import { Controller } from "@hotwired/stimulus";
import {
  DYNAMIC_VARIABLES,
  completions,
  openResponseModal,
  parseReference,
  previewReference,
  referenceStatus,
} from "lib/response_reference";

export default class extends Controller {
  static targets = ["input", "mount"];
  static values = {
    language: { type: String, default: "text" },
    readonly: Boolean,
    singleLine: Boolean,
    placeholder: String,
    variables: { type: Array, default: [] },
    variablesUrl: String,
    responses: { type: Array, default: [] },
    responsesUrl: String,
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

  // Another editor defined a variable that was missing: highlight and offer it here too.
  variableCreated({ detail }) {
    if (this.variablesValue.some((item) => item.name === detail.name)) return;

    this.variablesValue = [...this.variablesValue, detail];
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
      this.referenceClick(),
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
    if (name.startsWith("response.")) return referenceStatus(name, this.responsesValue);

    const variable = this.variablesValue.find((item) => item.name === name);
    if (!variable) return "missing";

    return variable.set ? "set" : "empty";
  }

  variableDecorations() {
    const cm = this.cm;
    const decorator = new cm.MatchDecorator({
      regexp: /\{\{\s*([^{}\s]+)\s*\}\}/g,
      decoration: (match) =>
        this.referenceName(match[1]) ? null : cm.Decoration.mark({ class: `cm-var cm-var-${this.variableStatus(match[1])}` }),
    });
    const marks = cm.ViewPlugin.fromClass(
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

    return [marks, this.referenceChips()];
  }

  // A valid `{{response.…}}` of this collection, once it is a reference to a known request.
  referenceName(name) {
    return name.startsWith("response.") && this.variableStatus(name) === "dynamic" ? name : null;
  }

  // Replaces each valid `{{response.…}}` with a chip naming the request, attribute and filter (the stored text is unchanged);
  // clicking it opens the modal.
  referenceChips() {
    const cm = this.cm;
    const controller = this;
    const chip = class extends cm.WidgetType {
      constructor(raw, text) {
        super();
        this.raw = raw;
        this.text = text;
      }
      eq(other) {
        return other.raw === this.raw && other.text === this.text;
      }
      toDOM(view) {
        const node = document.createElement("span");
        node.className = "cm-var cm-var-dynamic cm-ref-chip";
        node.textContent = this.text;
        node.addEventListener("mousedown", (event) => {
          event.preventDefault();
          if (controller.readonlyValue) return;

          const from = view.posAtDOM(node);
          controller.editReference(from, from + this.raw.length);
        });
        return node;
      }
      ignoreEvent() {
        return true;
      }
    };
    const decorator = new cm.MatchDecorator({
      regexp: /\{\{\s*(response\.[^{}\s]+)\s*\}\}/g,
      decoration: (match) => {
        const reference = this.referenceName(match[1]) && parseReference(match[1]);
        if (!reference) return null;

        const source = this.responsesValue.find(({ id }) => id === reference.requestId);
        const text = [source.name, reference.attribute, reference.filter].filter(Boolean).join(" · ");
        return cm.Decoration.replace({ widget: new chip(match[0], text) });
      },
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
      {
        decorations: (plugin) => plugin.decorations,
        provide: (plugin) =>
          cm.EditorView.atomicRanges.of((view) => view.plugin(plugin)?.decorations ?? cm.Decoration.none),
      },
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

  // Card for `{{response.…}}`: which request and attribute it reads, and the value it resolves to right now.
  responseCard(name) {
    const labels = this.labelsValue;
    const reference = parseReference(name);
    const source = this.responsesValue.find(({ id }) => id === reference?.requestId);
    const card = document.createElement("div");
    card.className = "cm-var-card";

    const value = document.createElement("div");
    value.className = "cm-var-card-value";
    card.append(value);
    if (source && this.hasResponsesUrlValue) {
      value.textContent = labels.responseLoading;
      previewReference(this.responsesUrlValue, name, labels, this.responsesValue).then(({ ok, text }) => {
        value.textContent = text;
        value.classList.add(ok ? "cm-var-card-set" : "cm-var-card-empty");
      });
    } else {
      value.textContent = labels.responseUnknown;
      value.classList.add("cm-var-card-missing");
    }

    const info = document.createElement("div");
    info.className = "cm-var-card-source";
    info.textContent = source
      ? [labels.response, source.name, reference.attribute, reference.filter].filter(Boolean).join(" · ")
      : labels.response;
    card.append(info);
    return { dom: card };
  }

  variableCard(name) {
    if (name.startsWith("response.")) return this.responseCard(name);

    const labels = this.labelsValue;
    const status = this.variableStatus(name);
    const variable = this.variablesValue.find((item) => item.name === name);
    const card = document.createElement("div");
    card.className = "cm-var-card";

    const editable =
      status === "set" ||
      status === "empty" ||
      (status === "missing" && this.hasVariablesUrlValue);
    const value = editable
      ? this.variableInput(variable ?? { name, set: false, value: "" })
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
    input.placeholder = variable.secret && variable.set ? variable.value : this.labelsValue[variable.url ? "empty" : "missing"];
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
    if (!variable.url) return this.createVariable(variable, value);

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

  // Defines a missing variable in the selected environment; once created, later edits of the card update it.
  async createVariable(variable, value) {
    if (!value) return;

    const response = await fetch(this.variablesUrlValue, {
      method: "POST",
      body: new URLSearchParams({
        "variable[key]": variable.name,
        "variable[value]": value,
      }),
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          ?.content,
      },
      credentials: "same-origin",
    });
    if (!response.ok) return;

    const created = await response.json();
    Object.assign(variable, created);
    window.dispatchEvent(new CustomEvent("variable:created", { detail: created }));
  }

  completeVariables(context) {
    const match = context.matchBefore(/\{\{[^{}\s]*/);
    if (!match) return null;

    const options = completions(match.text.slice(2), {
      variables: this.variablesValue,
      responses: this.responsesValue,
      labels: this.labelsValue,
    });
    return {
      from: match.from + 2,
      options: options.map((option) => ({
        label: option.label,
        type: option.status,
        detail: option.info,
        value: option.value,
        section: option.section,
        apply: (view, _completion, from, to) => this.applyOption(view, option, from, to),
      })),
    };
  }

  applyOption(view, option, from, to) {
    const closing =
      option.complete && view.state.sliceDoc(to, to + 2) !== "}}" ? "}}" : "";
    view.dispatch({
      changes: { from, to, insert: option.insert + closing },
      selection: { anchor: from + option.insert.length + closing.length },
      userEvent: "input.complete",
    });
    if (option.edit) this.editReference(from - 2, from + option.insert.length + 2);
  }

  // Opens the "edit tag" modal for the `{{response.…}}` between `from` and `to` and writes the result back.
  editReference(from, to) {
    const reference = parseReference(this.view.state.sliceDoc(from + 2, to - 2).trim());
    if (!reference || !this.hasResponsesUrlValue) return;

    openResponseModal({
      reference,
      responses: this.responsesValue,
      url: this.responsesUrlValue,
      labels: this.labelsValue,
      onDone: (name) => {
        this.view.dispatch({ changes: { from, to, insert: `{{${name}}}` } });
        this.view.focus();
      },
    });
  }

  // Clicking a `{{response.…}}` opens its modal, like clicking a tag in Insomnia.
  referenceClick() {
    return this.cm.EditorView.domEventHandlers({
      click: (event, view) => {
        if (this.readonlyValue) return false;

        const pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
        if (pos === null) return false;

        const line = view.state.doc.lineAt(pos);
        for (const match of line.text.matchAll(/\{\{\s*(response\.[^{}\s]+)\s*\}\}/g)) {
          const from = line.from + match.index;
          const to = from + match[0].length;
          if (pos <= from || pos >= to) continue;

          this.editReference(from, to);
          return true;
        }
        return false;
      },
    });
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
        fontSize: "0.8125rem",
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
        padding: singleLine ? "0" : "0.5rem 0",
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
        borderRadius: "0",
        boxShadow: "var(--dropdown-shadow)",
        color: "var(--body)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete": {
        padding: "0.25rem",
        minWidth: "16.25rem",
        maxWidth: "26.25rem",
        fontFamily: "var(--font-sans)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul": {
        fontFamily: "var(--font-mono)",
        fontSize: "0.78125rem",
        maxHeight: "16.25rem",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > completion-section": {
        display: "block",
        padding: "0.5rem 0.5rem 0.25rem",
        border: "none",
        color: "var(--muted)",
        fontFamily: "var(--font-sans)",
        fontSize: "0.65625rem",
        fontWeight: "600",
        letterSpacing: "0.06em",
        textTransform: "uppercase",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li": {
        display: "flex",
        flexWrap: "wrap",
        alignItems: "center",
        padding: "0.3125rem 0.5rem",
        borderRadius: "0",
        color: "var(--body)",
        lineHeight: "1.4",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li > .cm-completionLabel": {
        flex: "1",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li > .cm-completionDetail": {
        marginLeft: "1.5rem",
        fontFamily: "var(--font-sans)",
        fontSize: "0.6875rem",
        fontStyle: "normal",
        color: "var(--muted)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete > ul > li > .cm-var-value": {
        flexBasis: "100%",
        overflow: "hidden",
        marginLeft: "0.875rem",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",
        fontSize: "0.6875rem",
        color: "var(--muted)",
      },
      ".cm-tooltip.cm-tooltip-autocomplete ul li[aria-selected]": {
        backgroundColor: "var(--field)",
        color: "var(--ink)",
      },
      ".cm-tooltip.cm-tooltip-hover": {
        padding: "0.625rem",
        minWidth: "13.75rem",
        maxWidth: "26.25rem",
      },
      ".cm-var-card": { fontFamily: "var(--font-sans)", fontSize: "0.75rem" },
      ".cm-var-card-value": {
        padding: "0.5rem 0.625rem",
        border: "1px solid var(--line)",
        borderRadius: "0",
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
      ".cm-var-card-source": { marginTop: "0.5rem", color: "var(--muted)" },
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
