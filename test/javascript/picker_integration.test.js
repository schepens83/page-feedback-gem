import assert from "node:assert/strict"
import test from "node:test"

import { startFeedbackPicker } from "../../app/assets/javascripts/page_feedback/feedback_picker.js"
import { shouldSkipElement } from "../../app/assets/javascripts/page_feedback/element_capture.js"

// The picker and the skip predicate are unit-tested in isolation, which hides
// the interaction between them: hovering mutates the element that is about to
// be clicked. These tests wire the real modules together.
function classList(...initial) {
  const names = new Set(initial)
  const list = {
    add: (name) => names.add(name),
    remove: (name) => names.delete(name),
    contains: (name) => names.has(name),
    [Symbol.iterator]: () => names[Symbol.iterator]()
  }
  return list
}

function element(tagName, { parent = null, classes = [] } = {}) {
  return { tagName, classList: classList(...classes), parentElement: parent }
}

function pickerHarness() {
  const listeners = new Map()
  const body = element("BODY")
  const documentObject = {
    body: { ...body, appendChild() {} },
    createElement: () => ({ className: "", textContent: "", remove() {} }),
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: (name) => listeners.delete(name)
  }
  documentObject.body.classList = classList()
  return { listeners, documentObject }
}

test("an element picked after hovering it is still selectable", () => {
  const { listeners, documentObject } = pickerHarness()
  const target = element("ARTICLE", { parent: documentObject.body })
  let selected

  startFeedbackPicker({
    documentObject,
    shouldSkip: (node) => shouldSkipElement(node, { root: documentObject.body }),
    onPick: (node) => { selected = node }
  })

  // Hover first, exactly as a real pointer does before a click.
  listeners.get("mouseover")({ target })
  assert.equal(target.classList.contains("page-feedback-capture-highlight"), true)

  listeners.get("pointerdown")({ button: 0, target, preventDefault() {}, stopPropagation() {} })

  assert.equal(selected, target, "hovered element must remain pickable")
  assert.equal(documentObject.body.classList.contains("page-feedback-capture-mode"), false)
})

test("engine chrome stays unpickable after hover", () => {
  const { listeners, documentObject } = pickerHarness()
  const chrome = element("DIV", { parent: documentObject.body, classes: ["page-feedback-modal"] })
  let selected

  startFeedbackPicker({
    documentObject,
    shouldSkip: (node) => shouldSkipElement(node, { root: documentObject.body }),
    onPick: (node) => { selected = node }
  })

  listeners.get("mouseover")({ target: chrome })
  assert.equal(chrome.classList.contains("page-feedback-capture-highlight"), false)

  listeners.get("pointerdown")({ button: 0, target: chrome, preventDefault() {}, stopPropagation() {} })

  assert.equal(selected, undefined)
  assert.equal(documentObject.body.classList.contains("page-feedback-capture-mode"), true)
})
