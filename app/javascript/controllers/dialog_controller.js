import { Controller } from "@hotwired/stimulus"

// Native <dialog> opened as a modal as soon as it appears; clicking the backdrop or pressing Esc closes it.
export default class extends Controller {
  connect() {
    if (!this.element.open) this.element.showModal()
  }

  close() {
    this.element.close()
  }

  closed() {
    this.element.closest("turbo-frame")?.replaceChildren()
  }

  backdrop(event) {
    if (event.target === this.element) this.close()
  }
}
