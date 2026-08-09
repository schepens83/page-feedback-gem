import assert from "node:assert/strict"
import test from "node:test"

import {
  keyboardIntent,
  populateCaptureTargets
} from "../../app/assets/javascripts/page_feedback/capture_controller_support.js"

test("keyboardIntent maps Alt+F, Escape, and Ctrl+Enter without hijacking inputs", () => {
  const shortcut = { alt: true, key: "f" }

  assert.equal(keyboardIntent({ key: "f", altKey: true }, { shortcut, activeTag: "BODY" }), "toggle-picker")
  assert.equal(keyboardIntent({ key: "F", altKey: true }, { shortcut, activeTag: "INPUT" }), null)
  assert.equal(keyboardIntent({ key: "Escape" }, { modalOpen: true }), "close-modal")
  assert.equal(keyboardIntent({ key: "Escape" }, { modalOpen: false }), "stop-picker")
  assert.equal(keyboardIntent({ key: "Enter", ctrlKey: true }, { inCommentField: true }), "submit")
})

test("populateCaptureTargets writes the complete normalized submission payload", () => {
  const targets = Object.fromEntries(
    ["pagePath", "pageTitle", "cssSelector", "elementHtml", "controllerAction", "parentHtml",
      "viewport", "scrollY", "consoleErrors", "navigationHistory", "pointerType", "devicePixelRatio",
      "orientation"].map((name) => [name, { value: "" }])
  )

  populateCaptureTargets(targets, {
    capture: { selector: "#case > p", elementHtml: "<p>Hello</p>" },
    context: {
      parentHtml: "<section><p>Hello</p></section>",
      viewport: "1280x720",
      scrollY: 42,
      consoleErrors: "[]",
      navigationHistory: "[]",
      devicePixelRatio: "2",
      orientation: "portrait"
    },
    page: { path: "/cases/1", title: "Case 1" },
    controllerAction: "cases#show",
    pointerType: "touch"
  })

  assert.equal(targets.pagePath.value, "/cases/1")
  assert.equal(targets.controllerAction.value, "cases#show")
  assert.equal(targets.scrollY.value, 42)
  assert.equal(targets.pointerType.value, "touch")
  assert.equal(targets.devicePixelRatio.value, "2")
  assert.equal(targets.orientation.value, "portrait")
})
