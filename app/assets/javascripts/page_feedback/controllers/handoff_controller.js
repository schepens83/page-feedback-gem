import { Controller } from "@hotwired/stimulus"
import { decodeForward, previewLine } from "page_feedback/handoff"

export default class extends Controller {
  static targets = ["status", "form", "payload", "list", "submit"]

  connect() {
    this.render = this.render.bind(this)
    window.addEventListener("hashchange", this.render)
    this.render()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.render)
  }

  async render() {
    const result = await decodeForward(window.location.hash)
    if (result.state === "empty") return

    if (result.state === "invalid") {
      this.formTarget.hidden = true
      this.statusTarget.textContent = "This link does not contain a readable forward. Open it again from its forward page."
      return
    }

    const count = result.comments.length
    const from = result.source ? ` from ${result.source}` : ""
    this.statusTarget.textContent = `${count} ${count === 1 ? "comment" : "comments"}${from}. Check them, then import.`
    this.listTarget.replaceChildren(...result.comments.map((comment) => {
      const item = document.createElement("li")
      item.textContent = previewLine(comment)
      return item
    }))
    this.payloadTarget.value = result.json
    this.submitTarget.value = `Import ${count} ${count === 1 ? "comment" : "comments"}`
    this.formTarget.hidden = false
  }

  submit() {
    // The data now travels in the form; keep it out of the browser history.
    history.replaceState(null, "", window.location.pathname + window.location.search)
  }
}
