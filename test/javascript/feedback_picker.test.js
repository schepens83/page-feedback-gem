import assert from "node:assert/strict"
import test from "node:test"

import { startFeedbackPicker } from "../../app/assets/javascripts/page_feedback/feedback_picker.js"

function classList(...initial) {
  const names = new Set(initial)
  return {
    add: (name) => names.add(name),
    remove: (name) => names.delete(name),
    contains: (name) => names.has(name),
    [Symbol.iterator]: () => names[Symbol.iterator]()
  }
}

function fakeElement(tagName, { parent = null, rect = { top: 0, left: 0, width: 0, height: 0 } } = {}) {
  return {
    tagName,
    parentElement: parent,
    classList: classList(),
    closest: () => null,
    getBoundingClientRect: () => rect
  }
}

// Chrome nodes (mode indicator, overlay, confirm bar, and its buttons) are
// created via documentObject.createElement and need their own listener maps,
// classList, style object, and appendChild/remove so the picker can wire and
// tear them down like real DOM nodes.
function fakeChromeElement() {
  const listeners = new Map()
  return {
    className: "",
    textContent: "",
    type: "",
    hidden: false,
    style: {},
    classList: classList(),
    children: [],
    appendChild(child) { this.children.push(child) },
    addEventListener(name, callback) { listeners.set(name, callback) },
    removeEventListener(name) { listeners.delete(name) },
    remove() { this.removed = true },
    dispatch(name, event) { listeners.get(name)?.(event) }
  }
}

function pointerEvent(overrides = {}) {
  return {
    isPrimary: true,
    button: 0,
    pointerId: 1,
    pointerType: "mouse",
    clientX: 0,
    clientY: 0,
    target: undefined,
    preventDefault() { this.defaultPrevented = true },
    stopPropagation() { this.propagationStopped = true },
    ...overrides
  }
}

function pickerHarness({ coarse = false } = {}) {
  const documentListeners = new Map()
  const windowListeners = new Map()
  const createdChrome = []
  const timeouts = []
  const body = {
    classList: classList(),
    children: [],
    appendChild(child) { this.children.push(child) }
  }
  const documentObject = {
    body,
    createElement: () => {
      const chrome = fakeChromeElement()
      createdChrome.push(chrome)
      return chrome
    },
    addEventListener: (name, callback) => documentListeners.set(name, callback),
    removeEventListener: (name) => documentListeners.delete(name)
  }
  const windowObject = {
    matchMedia: () => ({ matches: coarse }),
    addEventListener: (name, callback) => windowListeners.set(name, callback),
    removeEventListener: (name) => windowListeners.delete(name),
    setTimeout: (callback) => { timeouts.push(callback); return timeouts.length }
  }

  return { documentObject, windowObject, documentListeners, windowListeners, createdChrome, timeouts, body }
}

// Chrome creation order in the picker: indicator, overlay, confirm-bar label,
// add/parent/cancel buttons, then the confirm-bar container itself.
function chromeParts(createdChrome) {
  const [indicator, overlay, confirmLabel, addButton, parentButton, cancelButton, confirmBar] = createdChrome
  return { indicator, overlay, confirmLabel, addButton, parentButton, cancelButton, confirmBar }
}

test("mouse hover moves the highlight overlay onto the hovered element", () => {
  const { documentObject, windowObject, documentListeners, createdChrome } = pickerHarness()
  const target = fakeElement("ARTICLE", { rect: { top: 10, left: 20, width: 30, height: 40 } })

  startFeedbackPicker({ documentObject, windowObject, shouldSkip: () => false, onPick: () => {} })
  const { overlay } = chromeParts(createdChrome)
  documentListeners.get("pointerover")(pointerEvent({ pointerType: "mouse", target }))

  assert.equal(overlay.hidden, false)
  assert.equal(overlay.style.top, "10px")
  assert.equal(overlay.style.left, "20px")
  assert.equal(overlay.style.width, "30px")
  assert.equal(overlay.style.height, "40px")
})

test("a mouse tap under the move tolerance picks with pointerType mouse and prevents the click", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const target = fakeElement("ARTICLE")
  let picked

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: (element, meta) => { picked = { element, meta } }
  })

  documentListeners.get("pointerdown")(pointerEvent({ target, clientX: 5, clientY: 5 }))
  const up = pointerEvent({ target, clientX: 8, clientY: 7 })
  documentListeners.get("pointerup")(up)

  assert.equal(picked.element, target)
  assert.deepEqual(picked.meta, { pointerType: "mouse" })
  assert.equal(up.defaultPrevented, true)
  assert.equal(up.propagationStopped, true)
})

test("movement past the tolerance between down and up does not pick", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const target = fakeElement("ARTICLE")
  let picked = false

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: () => { picked = true }
  })

  documentListeners.get("pointerdown")(pointerEvent({ target, clientX: 0, clientY: 0 }))
  documentListeners.get("pointermove")(pointerEvent({ target, clientX: 30, clientY: 0 }))
  documentListeners.get("pointerup")(pointerEvent({ target, clientX: 30, clientY: 0 }))

  assert.equal(picked, false)
})

test("pointercancel clears the pending tap without picking", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const target = fakeElement("ARTICLE")
  let picked = false

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: () => { picked = true }
  })

  documentListeners.get("pointerdown")(pointerEvent({ target }))
  documentListeners.get("pointercancel")(pointerEvent({ target }))
  documentListeners.get("pointerup")(pointerEvent({ target }))

  assert.equal(picked, false)
})

test("a second concurrent pointerdown cancels the pending tap", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const first = fakeElement("ARTICLE")
  const second = fakeElement("SECTION")
  let picked = false

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: () => { picked = true }
  })

  documentListeners.get("pointerdown")(pointerEvent({ pointerId: 1, target: first }))
  documentListeners.get("pointerdown")(pointerEvent({ pointerId: 2, target: second }))
  documentListeners.get("pointerup")(pointerEvent({ pointerId: 1, target: first }))
  documentListeners.get("pointerup")(pointerEvent({ pointerId: 2, target: second }))

  assert.equal(picked, false)
})

test("a touch tap shows the confirm bar without picking, then Add feedback picks it", () => {
  const { documentObject, windowObject, documentListeners, createdChrome, body } = pickerHarness({ coarse: true })
  const target = fakeElement("ARTICLE")
  let picked

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: (element, meta) => { picked = { element, meta } }
  })
  const { overlay, confirmBar, confirmLabel, addButton } = chromeParts(createdChrome)

  documentListeners.get("pointerdown")(pointerEvent({ pointerType: "touch", target }))
  documentListeners.get("pointerup")(pointerEvent({ pointerType: "touch", target }))

  assert.equal(picked, undefined, "a touch tap only stages a candidate")
  assert.equal(overlay.hidden, false)
  assert.equal(confirmBar.hidden, false)
  assert.equal(confirmLabel.textContent, "Feedback on <article>")

  addButton.dispatch("click")

  assert.equal(picked.element, target)
  assert.deepEqual(picked.meta, { pointerType: "touch" })
  assert.equal(body.classList.contains("page-feedback-capture-mode"), false)
  assert.equal(confirmBar.removed, true)
})

test("a touch tap on a span inside a button promotes the candidate to the button", () => {
  const { documentObject, windowObject, documentListeners, createdChrome } = pickerHarness({ coarse: true })
  const button = fakeElement("BUTTON")
  const span = fakeElement("SPAN", { parent: button })
  span.closest = () => button
  let picked

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: (element, meta) => { picked = { element, meta } }
  })
  const { addButton } = chromeParts(createdChrome)

  documentListeners.get("pointerdown")(pointerEvent({ pointerType: "touch", target: span }))
  documentListeners.get("pointerup")(pointerEvent({ pointerType: "touch", target: span }))
  addButton.dispatch("click")

  assert.equal(picked.element, button)
})

test("Choose parent walks the candidate up but stops at body", () => {
  const { documentObject, windowObject, documentListeners, createdChrome, body } = pickerHarness({ coarse: true })
  const grandparent = fakeElement("SECTION", { parent: body })
  const parent = fakeElement("DIV", { parent: grandparent })
  const child = fakeElement("SPAN", { parent })
  let picked

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: (element, meta) => { picked = { element, meta } }
  })
  const { addButton, parentButton } = chromeParts(createdChrome)

  documentListeners.get("pointerdown")(pointerEvent({ pointerType: "touch", target: child }))
  documentListeners.get("pointerup")(pointerEvent({ pointerType: "touch", target: child }))

  parentButton.dispatch("click")
  parentButton.dispatch("click")
  parentButton.dispatch("click")
  addButton.dispatch("click")

  assert.equal(picked.element, grandparent, "choosing parent stays below the body boundary")
})

test("Cancel clears the candidate but keeps capture mode active", () => {
  const { documentObject, windowObject, documentListeners, createdChrome, body } = pickerHarness({ coarse: true })
  const target = fakeElement("ARTICLE")
  let picked = false

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: () => false,
    onPick: () => { picked = true }
  })
  const { overlay, confirmBar, cancelButton } = chromeParts(createdChrome)

  documentListeners.get("pointerdown")(pointerEvent({ pointerType: "touch", target }))
  documentListeners.get("pointerup")(pointerEvent({ pointerType: "touch", target }))
  cancelButton.dispatch("click")

  assert.equal(picked, false)
  assert.equal(overlay.hidden, true)
  assert.equal(confirmBar.hidden, true)
  assert.equal(confirmBar.removed, undefined, "capture mode is still active")
  assert.equal(body.classList.contains("page-feedback-capture-mode"), true)
})

test("clicks on non-chrome elements are blocked for the whole capture session", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const target = fakeElement("ARTICLE")

  startFeedbackPicker({ documentObject, windowObject, shouldSkip: () => false, onPick: () => {} })

  const first = pointerEvent({ target })
  documentListeners.get("click")(first)
  const second = pointerEvent({ target })
  documentListeners.get("click")(second)

  assert.equal(first.defaultPrevented, true)
  assert.equal(second.defaultPrevented, true)
  assert.equal(documentListeners.has("click"), true, "the blocker stays installed during capture")
})

test("a click after finish is blocked once, then the lingering blocker uninstalls itself", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const target = fakeElement("ARTICLE")

  startFeedbackPicker({ documentObject, windowObject, shouldSkip: () => false, onPick: () => {} })

  documentListeners.get("pointerdown")(pointerEvent({ target }))
  documentListeners.get("pointerup")(pointerEvent({ target }))
  assert.equal(documentListeners.has("click"), true, "the blocker lingers past teardown")

  const strayClick = pointerEvent({ target: fakeElement("SECTION") })
  documentListeners.get("click")(strayClick)

  assert.equal(strayClick.defaultPrevented, true)
  assert.equal(documentListeners.has("click"), false, "the blocker uninstalls after one lingering click")
})

test("the lingering click blocker falls back to a timeout when no click ever arrives", () => {
  const { documentObject, windowObject, documentListeners, timeouts } = pickerHarness()
  const target = fakeElement("ARTICLE")

  startFeedbackPicker({ documentObject, windowObject, shouldSkip: () => false, onPick: () => {} })

  documentListeners.get("pointerdown")(pointerEvent({ target }))
  documentListeners.get("pointerup")(pointerEvent({ target }))
  assert.equal(timeouts.length, 1)

  timeouts[0]()

  assert.equal(documentListeners.has("click"), false)
})

test("clicks on elements where shouldSkip is true pass through untouched", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const chrome = fakeElement("BUTTON")
  chrome.isChrome = true

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: (element) => Boolean(element.isChrome),
    onPick: () => {}
  })

  const event = pointerEvent({ target: chrome })
  documentListeners.get("click")(event)

  assert.equal(event.defaultPrevented, undefined)
  assert.equal(event.propagationStopped, undefined)
  assert.equal(documentListeners.has("click"), true)
})

test("shouldSkip on pointerdown lets engine chrome and confirm-bar buttons work natively", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const chrome = fakeElement("BUTTON")
  chrome.isChrome = true
  let picked = false

  startFeedbackPicker({
    documentObject,
    windowObject,
    shouldSkip: (element) => Boolean(element.isChrome),
    onPick: () => { picked = true }
  })

  documentListeners.get("pointerdown")(pointerEvent({ target: chrome }))
  documentListeners.get("pointerup")(pointerEvent({ target: chrome }))

  assert.equal(picked, false)
})

test("uses the coarse-pointer mode indicator copy when the media query matches", () => {
  const { documentObject, windowObject, createdChrome } = pickerHarness({ coarse: true })

  startFeedbackPicker({ documentObject, windowObject, shouldSkip: () => false, onPick: () => {} })

  const { indicator } = chromeParts(createdChrome)
  assert.match(indicator.textContent, /tap an element/)
})

test("stop is idempotent and safe to call after a pick has already torn down chrome", () => {
  const { documentObject, windowObject, documentListeners } = pickerHarness()
  const target = fakeElement("ARTICLE")

  const stop = startFeedbackPicker({ documentObject, windowObject, shouldSkip: () => false, onPick: () => {} })

  documentListeners.get("pointerdown")(pointerEvent({ target }))
  documentListeners.get("pointerup")(pointerEvent({ target }))

  assert.doesNotThrow(() => {
    stop()
    stop()
  })
})
