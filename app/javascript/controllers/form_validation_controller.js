import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  mark(event) {
    event.preventDefault();

    const field = event.target;
    field.setAttribute("aria-invalid", "true");

    if (field === this.firstInvalidField(field.form)) field.focus();
  }

  clear(event) {
    const field = event.target;
    if (field.checkValidity()) field.removeAttribute("aria-invalid");
  }

  firstInvalidField(form) {
    return Array.from(form.elements).find(
      (element) => element.willValidate && !element.checkValidity(),
    );
  }
}
