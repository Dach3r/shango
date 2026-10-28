import { Controller } from "@hotwired/stimulus";

// The response toolbar is rendered after the request form: ask the form to fill it in.
export default class extends Controller {
  connect() {
    document.getElementById("request_form")?.dispatchEvent(new CustomEvent("url-preview:refresh"));
  }
}
