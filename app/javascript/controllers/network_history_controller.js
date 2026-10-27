import { Controller } from "@hotwired/stimulus";

const LIMIT = 15;
const UNITS = [
  ["day", 86400],
  ["hour", 3600],
  ["minute", 60],
];

// Keeps the last runs of one network tool in this browser only (localStorage) and refills the form from them.
// A result partial announces a finished run with a `[data-history-entry]` element (label, detail, tone).
export default class extends Controller {
  static targets = ["form", "result", "list", "empty", "clear", "template"];
  static values = { key: String };

  connect() {
    this.entries = this.load();
    this.render();
    this.observer = new MutationObserver(() => this.capture());
    this.observer.observe(this.resultTarget, { childList: true });
  }

  disconnect() {
    this.observer?.disconnect();
  }

  capture() {
    const marker = this.resultTarget.querySelector("[data-history-entry]");
    if (!marker) return;

    const fields = {};
    new FormData(this.formTarget).forEach((value, name) => {
      if (name !== "authenticity_token" && typeof value === "string")
        fields[name] = value;
    });
    const signature = JSON.stringify(fields);
    const entry = {
      label: marker.dataset.label,
      detail: marker.dataset.detail,
      tone: marker.dataset.tone,
      at: Date.now(),
      fields,
    };

    this.entries = [
      entry,
      ...this.entries.filter((e) => JSON.stringify(e.fields) !== signature),
    ].slice(0, LIMIT);
    this.save();
    this.render();
  }

  restore(event) {
    const entry = this.entries[Number(event.currentTarget.dataset.index)];
    if (!entry) return;

    Object.entries(entry.fields).forEach(([name, value]) =>
      this.fill(name, value),
    );
  }

  clear() {
    this.entries = [];
    this.save();
    this.render();
  }

  fill(name, value) {
    const input = this.formTarget.querySelector(`[name="${CSS.escape(name)}"]`);
    if (!input || input.value === value) return;

    if (input.type === "hidden") {
      input
        .closest("[data-controller~=select]")
        ?.querySelector(`[data-select-target=option][data-value="${CSS.escape(value)}"]`)
        ?.click();
    } else {
      input.value = value;
    }
  }

  render() {
    const items = this.entries.map((entry, index) => {
      const item = this.templateTarget.content.cloneNode(true);
      item.querySelector("[data-part=label]").textContent = entry.label;
      item.querySelector("[data-part=detail]").textContent = entry.detail;
      item.querySelector("[data-part=time]").textContent = this.ago(entry.at);
      item.querySelector("[data-part=dot]").dataset.tone = entry.tone;
      item.querySelector("button").dataset.index = index;
      return item;
    });

    this.listTarget.replaceChildren(...items);
    this.emptyTarget.hidden = items.length > 0;
    this.clearTarget.hidden = items.length === 0;
  }

  ago(at) {
    const seconds = Math.round((at - Date.now()) / 1000);
    const format = new Intl.RelativeTimeFormat(
      document.documentElement.lang || undefined,
      { numeric: "auto" },
    );
    const [unit, size] = UNITS.find(([, size]) => Math.abs(seconds) >= size) || [
      "second",
      1,
    ];

    return format.format(Math.trunc(seconds / size), unit);
  }

  storageKey() {
    return `network:history:${this.keyValue}`;
  }

  load() {
    try {
      const entries = JSON.parse(localStorage.getItem(this.storageKey()));
      return Array.isArray(entries) ? entries : [];
    } catch (_) {
      return [];
    }
  }

  save() {
    try {
      localStorage.setItem(this.storageKey(), JSON.stringify(this.entries));
    } catch (_) {
      /* storage unavailable */
    }
  }
}
