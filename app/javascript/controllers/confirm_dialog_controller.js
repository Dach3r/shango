import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  static targets = ["message", "accept", "acceptLabel"];

  connect() {
    this.defaultLabel = this.acceptLabelTarget.textContent;
    Turbo.config.forms.confirm = (message, form, submitter, label) => this.ask(message, label ?? form?.dataset.confirmLabel);
  }

  ask(message, label) {
    this.messageTarget.textContent = message;
    this.acceptLabelTarget.textContent = label ?? this.defaultLabel;
    this.element.showModal();
    this.acceptTarget.focus();
    return new Promise((resolve) => {
      this.resolve = resolve;
    });
  }

  accept() {
    this.settle(true);
  }

  cancel() {
    this.settle(false);
  }

  backdrop(event) {
    if (event.target === this.element) this.cancel();
  }

  closed() {
    this.settle(false);
  }

  settle(result) {
    const resolve = this.resolve;
    this.resolve = null;
    if (this.element.open) this.element.close();
    resolve?.(result);
  }
}
