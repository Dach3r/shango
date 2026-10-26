import { Controller } from "@hotwired/stimulus"

// Keeps the URL field and the Params table in sync, like Postman: enabled params live in the
// query string; disabled ones stay only in the table. `{{variables}}` are never URL-encoded.
export default class extends Controller {
  static targets = ["url", "params"]

  connect() {
    this.syncing = false
  }

  urlChanged() {
    if (this.syncing) return

    this.syncing = true
    this.paramsController()?.replaceEnabled(this.parse(this.urlTarget.value))
    this.syncing = false
  }

  paramsChanged(event) {
    if (this.syncing) return

    this.syncing = true
    const query = event.detail.rows.filter((row) => row.enabled && row.key !== "").map((row) => this.pair(row)).join("&")
    const [base] = this.urlTarget.value.split(/[?#]/)
    const hash = this.urlTarget.value.includes("#") ? `#${this.urlTarget.value.split("#").slice(1).join("#")}` : ""
    const next = `${base}${query ? `?${query}` : ""}${hash}`

    this.editorController()?.setValue(next)
    this.syncing = false
  }

  parse(url) {
    const query = url.split("#")[0].split("?").slice(1).join("?")
    if (!query) return []

    return query.split("&").filter(Boolean).map((part) => {
      const [key, ...rest] = part.split("=")
      return [this.decode(key), this.decode(rest.join("="))]
    })
  }

  pair(row) {
    return `${this.encode(row.key)}=${this.encode(row.value)}`
  }

  encode(text) {
    return text.split(/(\{\{[^}]*\}\})/).map((part) => (part.startsWith("{{") ? part : encodeURIComponent(part))).join("")
  }

  decode(text) {
    return text.split(/(\{\{[^}]*\}\})/).map((part) => {
      if (part.startsWith("{{")) return part
      try { return decodeURIComponent(part.replaceAll("+", " ")) } catch (_) { return part }
    }).join("")
  }

  paramsController() {
    return this.application.getControllerForElementAndIdentifier(this.paramsTarget, "key-value-table")
  }

  editorController() {
    const element = this.urlTarget.closest("[data-controller~='code-editor']")
    return element && this.application.getControllerForElementAndIdentifier(element, "code-editor")
  }
}
