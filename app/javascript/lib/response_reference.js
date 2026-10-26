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
const REQUEST_STAGE = /^response\.(body|raw|header|url)\.[^.]*$/;
// What follows the request id: a JSONPath starts at `$`, a header name is typed as is.
const CONTINUATION = { body: ".$.", header: ".", raw: "", url: "" };

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

// Completions for the text typed after `{{`. `offset` is how much of that text is a fixed prefix (not filtered by the
// typed text); each option has `insert` (what to write), `complete` (false keeps `}}` out) and `reopen` (ask again).
export function completions(query, { variables, responses, labels }) {
  const stage = REQUEST_STAGE.exec(query);
  if (stage) {
    const attribute = stage[1];
    const offset = `response.${attribute}.`.length;
    return {
      offset,
      options: responses.map(({ id, name, method, folder }) => ({
        label: name,
        insert: `${id}${CONTINUATION[attribute]}`,
        status: "dynamic",
        info: [method, folder].filter(Boolean).join(" · "),
        section: { name: labels.response, rank: 2 },
        complete: !["body", "header"].includes(attribute),
      })),
    };
  }
  if (query.startsWith("response.") && parseReference(query)) return { offset: 0, options: [] };

  const environment = { name: labels.environment, rank: 0 };
  const dynamic = { name: labels.dynamic, rank: 1 };
  const response = { name: labels.response, rank: 2 };
  return {
    offset: 0,
    options: [
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
      ...(responses.length
        ? ATTRIBUTES.map((attribute) => ({
            label: `response.${attribute}`,
            insert: `response.${attribute}.`,
            status: "dynamic",
            info: labels[`response${attribute[0].toUpperCase()}${attribute.slice(1)}`],
            section: response,
            complete: false,
            reopen: true,
          }))
        : []),
    ],
  };
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
