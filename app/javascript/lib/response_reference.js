// Shared by the code editor and the plain-input autocomplete: `{{response.<attr>.<request_id>[.<filter>]}}` references
// take a value from the latest response of another request in the same collection.

export const DYNAMIC_VARIABLES = {
  $guid: "guid",
  $isoTimestamp: "isoTimestamp",
  $randomInt: "randomInt",
  $timestamp: "timestamp",
};

export const ATTRIBUTES = ["body", "raw", "header", "url"];

const REFERENCE =
  /^response\.(body|raw|header|url)\.([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:\.(.+))?$/i;
export const FILTERED = ["body", "header"];
// What a freshly inserted reference reads until the user edits it in the modal.
export const DEFAULT_FILTERS = { body: "$", header: "Content-Type" };

export function buildReference({ attribute, requestId, filter }) {
  return `response.${attribute}.${requestId}${FILTERED.includes(attribute) ? `.${filter}` : ""}`;
}

export function parseReference(name) {
  const match = REFERENCE.exec(name);
  if (!match) return null;

  return { attribute: match[1], requestId: match[2].toLowerCase(), filter: match[3] };
}

// "dynamic" for a reference to a request of this collection, "missing" otherwise.
export function referenceStatus(name, responses) {
  const reference = parseReference(name);
  const known = reference && responses.some(({ id }) => id === reference.requestId);
  return known ? "dynamic" : "missing";
}

// Completions for the text typed after `{{`. Each option has `insert` (what to write), `complete` (false keeps `}}` out)
// and, for `response.*`, `edit` (a ready reference is written and the editing modal opens).
export function completions(query, { variables, responses, labels }) {
  if (query.startsWith("response.") && parseReference(query)) return [];

  const environment = { name: labels.environment, rank: 0 };
  const dynamic = { name: labels.dynamic, rank: 1 };
  const response = { name: labels.response, rank: 2 };
  const first = responses[0];
  return [
    ...variables.map(({ name, set, value }) => ({
      label: name,
      insert: name,
      status: set ? "set" : "empty",
      info: set ? "" : labels.empty,
      value,
      section: environment,
      complete: true,
    })),
    ...Object.entries(DYNAMIC_VARIABLES).map(([name, key]) => ({
      label: name,
      insert: name,
      status: "dynamic",
      info: labels[key],
      section: dynamic,
      complete: true,
    })),
    ...(first
      ? ATTRIBUTES.map((attribute) => ({
          label: `response.${attribute}`,
          insert: buildReference({ attribute, requestId: first.id, filter: DEFAULT_FILTERS[attribute] }),
          status: "dynamic",
          info: labels[`response${attribute[0].toUpperCase()}${attribute.slice(1)}`],
          section: response,
          complete: true,
          edit: true,
        }))
      : []),
  ];
}

// Asks the server what a reference resolves to; resolves to the text a card or hint can show.
export async function previewReference(url, name, labels, responses) {
  const reference = parseReference(name);
  const source = responses.find(({ id }) => id === reference?.requestId);
  try {
    const response = await fetch(`${url}?${new URLSearchParams({ name })}`, {
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    });
    const { status, value } = await response.json();
    if (status === "ok") return { ok: true, text: value };

    const key = {
      no_response: "responseNoResponse",
      no_match: "responseNoMatch",
      unknown_request: "responseUnknown",
    }[status] ?? "responseInvalid";
    return { ok: false, text: labels[key].replace("%{request}", source?.name ?? "") };
  } catch {
    return { ok: false, text: labels.responseInvalid };
  }
}

const SELECT =
  "block h-10 w-full rounded-lg border border-line bg-field px-3 text-sm text-ink transition focus:border-solid focus:bg-field-focus focus:ring-2 focus:ring-solid/40 focus:outline-none disabled:opacity-50";
const LABEL = "mb-1 block text-xs font-medium text-muted";

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function field(label, control) {
  const wrapper = element("div");
  wrapper.append(element("label", LABEL, label), control);
  return wrapper;
}

function select(options, value, onChange, disabled = false) {
  const control = element("select", SELECT);
  options.forEach(([optionValue, text]) => {
    const option = element("option", "", text);
    option.value = optionValue;
    control.append(option);
  });
  control.value = value;
  control.disabled = disabled;
  control.addEventListener("change", () => onChange(control.value));
  return control;
}

// The "Edit tag" dialog: pick the attribute, the request and the filter of a response reference and see its live value.
// `reference` is a parsed reference (attribute, requestId, filter); `onDone` gets the new reference name.
export function openResponseModal({ reference, responses, url, labels, onDone }) {
  if (responses.length === 0) return;

  const state = {
    attribute: reference.attribute,
    requestId: responses.some(({ id }) => id === reference.requestId) ? reference.requestId : responses[0].id,
    filters: { ...DEFAULT_FILTERS, [reference.attribute]: reference.filter ?? "" },
  };
  const dialog = element(
    "dialog",
    "modal m-auto max-h-[90dvh] w-[calc(100%-2rem)] max-w-lg flex-col overflow-hidden rounded-3xl border border-line bg-card p-0 text-body shadow-dropdown open:flex backdrop:bg-night-1000/60 backdrop:backdrop-blur-sm",
  );
  const header = element("header", "flex shrink-0 items-start gap-3 px-6 pt-5 pb-4");
  const close = element("button", "-mr-2 flex size-8 shrink-0 cursor-pointer items-center justify-center rounded-lg text-muted transition hover:bg-field hover:text-ink", "✕");
  close.type = "button";
  close.setAttribute("aria-label", labels.responseClose);
  header.append(element("h2", "min-w-0 flex-1 pt-0.5 text-lg font-semibold tracking-tight text-ink", labels.responseEditTitle), close);

  const body = element("div", "min-h-0 flex-1 space-y-4 overflow-y-auto px-6 pb-6");
  const functionSelect = select([["response", labels.responseFunction]], "response", () => {}, true);
  const attributeSelect = select(
    ATTRIBUTES.map((attribute) => [attribute, labels[`response${attribute[0].toUpperCase()}${attribute.slice(1)}`]]),
    state.attribute,
    (value) => {
      state.attribute = value;
      sync();
    },
  );
  const requestSelect = select(
    responses.map(({ id, name, method, folder }) => [id, `${folder ? `[${folder}] ` : ""}${method} ${name}`]),
    state.requestId,
    (value) => {
      state.requestId = value;
      refresh();
    },
  );
  const filterLabel = element("label", LABEL);
  const filterInput = element("input", `${SELECT} font-mono`);
  filterInput.autocomplete = "off";
  filterInput.spellcheck = false;
  filterInput.addEventListener("input", () => {
    state.filters[state.attribute] = filterInput.value;
    refresh();
  });
  const filterField = element("div");
  filterField.append(filterLabel, filterInput);
  const triggerSelect = select([["never", labels.responseTriggerNever]], "never", () => {}, true);
  const hint = element("p", "mt-1 text-xs text-muted", labels.responseTriggerHint);

  const previewHeader = element("div", "mb-1 flex items-center justify-between");
  const refreshButton = element("button", "cursor-pointer text-xs text-muted transition hover:text-ink", `${labels.responseRefresh} ↻`);
  refreshButton.type = "button";
  previewHeader.append(element("span", "text-xs font-medium text-muted", labels.responsePreview), refreshButton);
  const preview = element("textarea", "block min-h-28 w-full resize-y rounded-lg border border-line bg-field px-3 py-2 font-mono text-xs text-ink focus:outline-none");
  preview.readOnly = true;
  const previewField = element("div", "border-t border-line pt-4");
  previewField.append(previewHeader, preview);

  const triggerField = field(labels.responseTrigger, triggerSelect);
  triggerField.append(hint);
  body.append(
    field(labels.responseFunctionLabel, functionSelect),
    field(labels.responseAttribute, attributeSelect),
    field(labels.responseRequest, requestSelect),
    filterField,
    triggerField,
    previewField,
  );

  const footer = element("footer", "flex shrink-0 items-center justify-end gap-2 border-t border-line bg-field/60 px-6 py-3.5");
  const done = element(
    "button",
    "inline-flex cursor-pointer items-center justify-center rounded-lg bg-solid px-4 py-2 text-sm font-medium text-on-solid shadow-sm transition hover:bg-solid-hover focus:outline-none focus-visible:ring-2 focus-visible:ring-solid/50 disabled:cursor-not-allowed disabled:opacity-60",
    labels.responseDone,
  );
  done.type = "button";
  footer.append(done);
  dialog.append(header, body, footer);

  const filter = () => (FILTERED.includes(state.attribute) ? state.filters[state.attribute].trim() : null);
  const valid = () => filter() === null || (filter() !== "" && !/\s/.test(filter()));
  const name = () => buildReference({ ...state, filter: filter() });

  let ticket = 0;
  let timer = null;
  function refresh(immediate = false) {
    done.disabled = !valid();
    clearTimeout(timer);
    const current = ++ticket;
    if (!valid()) {
      preview.value = labels.responseInvalid;
      return;
    }
    preview.value = labels.responseLoading;
    timer = setTimeout(
      async () => {
        const { text } = await previewReference(url, name(), labels, responses);
        if (current === ticket) preview.value = text;
      },
      immediate ? 0 : 300,
    );
  }
  function sync() {
    const filtered = FILTERED.includes(state.attribute);
    filterField.hidden = !filtered;
    filterLabel.textContent = state.attribute === "header" ? labels.responseFilterHeader : labels.responseFilterBody;
    filterInput.value = state.filters[state.attribute] ?? "";
    refresh(true);
  }

  refreshButton.addEventListener("click", () => refresh(true));
  done.addEventListener("click", () => {
    if (!valid()) return;

    onDone(name());
    dialog.close();
  });
  close.addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
  dialog.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && event.target === filterInput) {
      event.preventDefault();
      done.click();
    }
  });
  dialog.addEventListener("close", () => {
    clearTimeout(timer);
    dialog.remove();
  });

  document.body.append(dialog);
  sync();
  dialog.showModal();
}
