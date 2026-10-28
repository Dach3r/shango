import { Controller } from "@hotwired/stimulus";

// The domain placeholder follows the record type: PTR asks for an IP address instead of a domain.
export default class extends Controller {
  static targets = ["field", "type"];
  static values = { domain: String, ptr: String };

  connect() {
    this.sync();
  }

  sync() {
    this.fieldTarget.placeholder = this.typeTarget.value === "PTR" ? this.ptrValue : this.domainValue;
  }
}
