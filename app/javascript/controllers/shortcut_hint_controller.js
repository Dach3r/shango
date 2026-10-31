import { Controller } from "@hotwired/stimulus";

// Shows the key combination that opens the command palette for the visitor's system: ⌘ K on macOS, Ctrl K on Windows and
// Linux. Elsewhere (phones, tablets, unknown systems) there is no shortcut worth advertising, so the hint stays hidden.
export default class extends Controller {
  static targets = ["key"];

  connect() {
    const platform = this.platform();
    this.element.dataset.platform = platform;

    const label = { mac: "⌘ K", windows: "Ctrl K", linux: "Ctrl K" }[platform];
    if (!label) return;

    this.keyTarget.textContent = label;
    this.keyTarget.hidden = false;
  }

  platform() {
    const hint = navigator.userAgentData?.platform || navigator.platform || "";
    const agent = navigator.userAgent || "";

    if (/android/i.test(agent)) return "other";
    if (/iphone|ipad|ipod/i.test(agent)) return "other";
    if (/mac/i.test(hint) || /macintosh/i.test(agent)) return "mac";
    if (/win/i.test(hint) || /windows/i.test(agent)) return "windows";
    if (/linux|x11|cros/i.test(hint) || /linux|x11|cros/i.test(agent)) return "linux";
    return "other";
  }
}
