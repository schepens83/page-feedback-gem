import assert from "node:assert/strict"
import test from "node:test"

import { startFeedbackPicker } from "../../app/assets/javascripts/page_feedback/feedback_picker.js"
import { shouldSkipElement } from "../../app/assets/javascripts/page_feedback/element_capture.js"

// The picker and the skip predicate are unit-tested in isolation, which hides
// the interaction between them: hovering repositions the overlay onto the
// element that is about to be tapped, and engine chrome (including the
// picker's own confirm-bar buttons) must stay off-limits. These tests wire
// the real modules together.
function classList(...initial) {
  const names = new Set(initial)
  return {
    add: (name) => names.add(name),
    remove: (name) => names.delete(name),
    contains: (name) => names.has(name),
    [Symbol.iterator]: () => names[Symbol.iterator]()
  }
}

function element(tagName, { parent = null, classes = [] } = {}) {
  return {
    tagName,
    classList: classList(...classes),
    parentElement: parent,
    closest: () => null,
    getBoundingClientRect: () => ({ top: 0, left: 0, width: 0, height: 0 })
  }
}

function fakeChromeElement() {
  const listeners = new Map()
  return {
    className: "",
    textContent: "",
    hidden: false,
    style: {},
    classList: classList(),
    appendChild() {},
    addEventListener(name, callback) { listeners.set(name, callback) },
    removeEventListener(name) { listeners.delete(name) },
    remove() {},
    dispatch(name, event) { listeners.get(name)?.(event) }
  }
}

function pickerHarness() {
  const documentListeners = new Map()
  const windowListeners = new Map()
  const body = { classList: classList(), appendChild() {} }
  const documentObject = {
    body,
    createElement: () => fakeChromeElement(),
    addEventListener: (name, callback) => documentListeners.set(name, callback),
    removeEventListener: (name) => documentListeners.delete(name)
  }
  const windowObject = {
    matchMedia: () => ({ matches: false }),
    addEventListener: (name, callback) => windowListeners.set(name, callback),
    removeEventListener: (name) => windowListeners.delete(name),
    setTimeout: () => 1
  }

  return { documentListeners, windowListeners, documentObject, windowObject, body }
}

function pointerEvent(overrides = {}) {
  return {
    isPrimary: true,
    button: 0,
    pointerId: 1,
    pointerType: "mouse",
    clientX: 0,
    clientY: 0,
    preventDefault() {},
    stopPropagation() {},
    ...overrides
  }
}

test("an element hovered and then tapped with the mouse is still selectable", () => {
  const { documentListeners, documentObject, windowObject, body } = pickerHarness()
  const target = element("ARTICLE", { parent: body })
  let selected

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: (node) => shouldSkipElement(node, { root: body }),
    onPick: (node) => { selected = node }
  })

  // Hover first, exactly as a real mouse does before a click.
  documentListeners.get("pointerover")(pointerEvent({ target }))
  documentListeners.get("pointerdown")(pointerEvent({ target }))
  documentListeners.get("pointerup")(pointerEvent({ target }))

  assert.equal(selected, target, "hovered element must remain pickable")
  assert.equal(body.classList.contains("page-feedback-capture-mode"), false)
})

test("engine chrome stays unpickable after hover", () => {
  const { documentListeners, documentObject, windowObject, body } = pickerHarness()
  const chrome = element("DIV", { parent: body, classes: ["page-feedback-modal"] })
  let selected

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: (node) => shouldSkipElement(node, { root: body }),
    onPick: (node) => { selected = node }
  })

  documentListeners.get("pointerover")(pointerEvent({ target: chrome }))
  documentListeners.get("pointerdown")(pointerEvent({ target: chrome }))
  documentListeners.get("pointerup")(pointerEvent({ target: chrome }))

  assert.equal(selected, undefined)
  assert.equal(body.classList.contains("page-feedback-capture-mode"), true)
})

test("interactive host elements are pickable now that only engine chrome is excluded", () => {
  const { documentListeners, documentObject, windowObject, body } = pickerHarness()
  const nav = element("NAV", { parent: body })
  const link = element("A", { parent: nav })
  let selected

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: (node) => shouldSkipElement(node, { root: body }),
    onPick: (node) => { selected = node }
  })

  documentListeners.get("pointerdown")(pointerEvent({ target: link }))
  documentListeners.get("pointerup")(pointerEvent({ target: link }))

  assert.equal(selected, link)
})
