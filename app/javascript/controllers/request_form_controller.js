import { Controller } from "@hotwired/stimulus"

// The request editor: sends the form to the executions endpoint (saving edits first) and swaps the
// response panel with the returned Turbo Stream. Ctrl/Cmd+Enter sends, Ctrl/Cmd+S saves.
export default class extends Controller {
  static targets = ["form", "send", "failure"]
  static values = { runUrl: String, curlUrl: String }

  async run(event) {
    event?.preventDefault()
    if (this.running) return

    this.running = true
    this.setBusy(true)
    const body = new FormData(this.formTarget)
    body.delete("_method")

    try {
      const response = await fetch(this.runUrlValue, {
        method: "POST",
        body,
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
        credentials: "same-origin"
      })
      const text = await response.text()
      if (response.headers.get("Content-Type")?.includes("turbo-stream")) {
        window.Turbo.renderStreamMessage(text)
      } else {
        this.showFailure()
      }
    } catch (_) {
      this.showFailure()
    } finally {
      this.running = false
      this.setBusy(false)
    }
  }

  showFailure() {
    const panel = document.getElementById("response_panel")
    if (panel && this.hasFailureTarget) panel.replaceChildren(this.failureTarget.content.cloneNode(true))
  }

  save(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  async copyCurl(event) {
    const button = event.currentTarget
    const response = await fetch(this.curlUrlValue, { headers: { Accept: "application/json" }, credentials: "same-origin" })
    const { curl, error } = await response.json()
    if (error) return this.flash(button, error)

    await navigator.clipboard.writeText(curl)
    this.flash(button, button.dataset.copiedLabel)
  }

  setBusy(busy) {
    if (!this.hasSendTarget) return

    this.sendTarget.disabled = busy
    this.sendTarget.dataset.busy = String(busy)
  }

  flash(button, text) {
    const label = button.querySelector("[data-label]") || button
    const original = label.textContent
    label.textContent = text
    setTimeout(() => { label.textContent = original }, 1800)
  }
}
