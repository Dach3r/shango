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

// The "Edit tag" dialog: pick the attribute, the request and the filter of a response reference and see its live value.
// It is cloned from the server-rendered `#response-reference-template`. `reference` is a parsed reference (attribute,
// requestId, filter); `onDone` gets the new reference name.
export function openResponseModal({ reference, responses, url, labels, onDone }) {
  const template = document.getElementById("response-reference-template");
  if (responses.length === 0 || !template) return;

  const dialog = template.content.firstElementChild.cloneNode(true);
  const part = (name) => dialog.querySelector(`[data-response-reference='${name}']`);
  const input = (name) => dialog.querySelector(`input[name='${name}']`);
  const state = {
    attribute: reference.attribute,
    requestId: responses.some(({ id }) => id === reference.requestId) ? reference.requestId : responses[0].id,
    filters: { ...DEFAULT_FILTERS, [reference.attribute]: reference.filter ?? "" },
  };
  const filterField = part("filter-field");
  const filterLabel = part("filter-label");
  const filterInput = part("filter");
  const preview = part("preview");
  const done = part("done");
  input("attribute").value = state.attribute;
  input("request").value = state.requestId;

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
    filterField.hidden = !FILTERED.includes(state.attribute);
    filterLabel.textContent = state.attribute === "header" ? labels.responseFilterHeader : labels.responseFilterBody;
    filterInput.value = state.filters[state.attribute] ?? "";
    refresh(true);
  }

  input("attribute").addEventListener("change", ({ target }) => {
    state.attribute = target.value;
    sync();
  });
  input("request").addEventListener("change", ({ target }) => {
    state.requestId = target.value;
    refresh();
  });
  filterInput.addEventListener("input", () => {
    state.filters[state.attribute] = filterInput.value;
    refresh();
  });
  filterInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;

    event.preventDefault();
    done.click();
  });
  part("refresh").addEventListener("click", () => refresh(true));
  done.addEventListener("click", () => {
    if (!valid()) return;

    onDone(name());
    dialog.close();
  });
  dialog.addEventListener("close", () => {
    clearTimeout(timer);
    dialog.remove();
  });

  document.body.append(dialog);
  sync();
}
