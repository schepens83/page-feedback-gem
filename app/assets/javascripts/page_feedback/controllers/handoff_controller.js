import { Controller } from "@hotwired/stimulus"
import { copyText } from "page_feedback/clipboard"
import { unpack } from "page_feedback/handoff"

function browserStorage() {
  try {
    return window.localStorage
  } catch {
    return null
  }
}

export default class extends Controller {
  static targets = ["status", "actions", "body", "copyStatus"]

  connect() {
    this.render = this.render.bind(this)
    window.addEventListener("hashchange", this.render)
    this.render()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.render)
  }

  async render() {
    const result = await unpack(window.location.hash, browserStorage())

    if (result.state === "partial") {
      this.statusTarget.textContent =
        `Received ${result.received} of ${result.total} codes. Scan the next one.`
    } else if (result.state === "invalid") {
      this.statusTarget.textContent = "This link does not contain a readable export. Scan the code again."
    } else if (result.state === "complete") {
      this.text = result.text
      this.statusTarget.textContent = "Export unpacked."
      this.bodyTarget.textContent = result.text
      this.bodyTarget.hidden = false
      this.actionsTarget.hidden = false
      // Keep the export out of the browser history once it has been read.
      history.replaceState(null, "", window.location.pathname + window.location.search)
    }
  }

  async copy() {
    const copied = await copyText(this.text || "")
    this.copyStatusTarget.textContent = copied ? "Copied" : "Copy failed — select the Markdown below"
  }
}
