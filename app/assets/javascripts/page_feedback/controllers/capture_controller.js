import { Controller } from "@hotwired/stimulus"
import { capturePageContext, installContextRecorder } from "page_feedback/context_recorder"
import { captureElement, shouldSkipElement } from "page_feedback/element_capture"
import { startFeedbackPicker } from "page_feedback/feedback_picker"
import { keyboardIntent, populateCaptureTargets } from "page_feedback/capture_controller_support"

export default class extends Controller {
  static targets = [
    "modal", "form", "tagName", "selectorLabel", "preview", "commentText", "categoryInput",
    "pagePath", "pageTitle", "controllerAction", "cssSelector", "elementHtml", "parentHtml",
    "viewport", "scrollY", "consoleErrors", "navigationHistory"
  ]

  static values = {
    controllerAction: String,
    defaultCategory: String,
    ignoredClasses: Array,
    shortcut: Object
  }

  connect() {
    installContextRecorder()
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener("keydown", this.handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleGlobalKeydown)
    this.stopFeedbackMode()
  }

  activate(event) {
    event.preventDefault()
    this.feedbackStop ? this.stopFeedbackMode() : this.startFeedbackMode()
  }

  closeFromBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  close() {
    if (this.hasModalTarget) this.modalTarget.hidden = true
  }

  submitWithShortcut(event) {
    const intent = keyboardIntent(event, { inCommentField: true })
    if (intent !== "submit") return

    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  submitted() {
    window.setTimeout(() => {
      this.element.querySelectorAll(".page-feedback-toast").forEach((toast) => toast.remove())
    }, 4_500)
  }

  modalTargetConnected(modal) {
    if (!modal.hidden && this.hasCommentTextTarget) this.commentTextTarget.focus()
  }

  handleGlobalKeydown(event) {
    const intent = keyboardIntent(event, {
      shortcut: this.shortcutValue,
      activeTag: document.activeElement?.tagName,
      modalOpen: this.hasModalTarget && !this.modalTarget.hidden
    })
    if (!intent) return

    if (intent === "close-modal") this.close()
    if (intent === "stop-picker") this.stopFeedbackMode()
    if (intent === "toggle-picker") this.activate(event)
  }

  startFeedbackMode() {
    this.feedbackStop ||= startFeedbackPicker({
      shouldSkip: (element) => shouldSkipElement(element),
      onPick: (element) => this.openModal(captureElement(element, {
        ignoredClasses: this.ignoredClassesValue
      }))
    })
  }

  stopFeedbackMode() {
    if (!this.feedbackStop) return

    this.feedbackStop()
    this.feedbackStop = undefined
  }

  openModal(capture) {
    const context = capturePageContext(capture.parentHtml)
    this.formTarget.reset()
    this.categoryInputTarget.value = this.defaultCategoryValue
    this.commentTextTarget.value = ""
    this.tagNameTarget.textContent = `Feedback on <${capture.tagName}>`
    this.selectorLabelTarget.textContent = this.truncate(capture.selector, 80)
    this.previewTarget.textContent = this.truncate(capture.elementHtml, 300)
    populateCaptureTargets(this.captureTargets, {
      capture,
      context,
      page: { path: window.location.pathname, title: document.title },
      controllerAction: this.controllerActionValue
    })
    this.modalTarget.hidden = false
    this.commentTextTarget.focus()
  }

  get captureTargets() {
    return Object.fromEntries([
      "pagePath", "pageTitle", "controllerAction", "cssSelector", "elementHtml", "parentHtml",
      "viewport", "scrollY", "consoleErrors", "navigationHistory"
    ].map((name) => [name, this[`${name}Target`]]))
  }

  truncate(value, maximum) {
    return value.length > maximum ? `${value.slice(0, maximum - 3)}...` : value
  }
}
