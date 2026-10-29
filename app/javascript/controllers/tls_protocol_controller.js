import { Controller } from "@hotwired/stimulus";

// A blank port means the usual one of the chosen protocol, so the placeholder shows it.
export default class extends Controller {
  static targets = ["port", "protocol"];
  static values = { ports: Object };

  connect() {
    this.sync();
  }

  sync() {
    this.portTarget.placeholder = this.portsValue[this.protocolTarget.value] ?? "";
  }
}
