import { Controller } from "@hotwired/stimulus"
import { copyText } from "page_feedback/clipboard"

export default class extends Controller {
  static targets = ["status"]
  static values = { text: String }

  async copy() {
    const copied = await copyText(this.textValue)
    this.statusTarget.textContent = copied ? "Copied" : "Copy failed — select the Markdown below"
  }
}
