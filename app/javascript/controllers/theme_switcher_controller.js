import { Controller } from "@hotwired/stimulus"

// Turbo only swaps <body> on visits, so <html data-theme> must be updated here;
// the form submit still persists the choice in the theme cookie.
export default class extends Controller {
  apply({ params: { theme } }) {
    document.documentElement.dataset.theme = theme
  }
}
