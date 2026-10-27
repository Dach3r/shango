import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  apply({ params: { locale } }) {
    document.documentElement.lang = locale;
  }
}
