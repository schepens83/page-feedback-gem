import assert from "node:assert/strict"
import test from "node:test"

import { startCaptureModeStatus } from "../../app/assets/javascripts/page_feedback/capture_mode_status.js"

function classList() {
  const names = new Set()
  return {
    add: (name) => names.add(name),
    remove: (name) => names.delete(name),
    contains: (name) => names.has(name)
  }
}

function fakeTrigger() {
  const attributes = new Map()
  return {
    textContent: "Give page feedback",
    classList: classList(),
    attributes,
    setAttribute: (name, value) => attributes.set(name, value),
    getAttribute: (name) => attributes.get(name)
  }
}

function fakeDocument() {
  const body = { children: [], appendChild(child) { this.children.push(child) } }
  return {
    body,
    createElement: () => ({
      className: "",
      textContent: "",
      remove() { this.removed = true }
    })
  }
}

function fakeWindow({ coarse = false } = {}) {
  return { matchMedia: () => ({ matches: coarse }) }
}

test("the trigger becomes the mode bar and returns to its own label", () => {
  const trigger = fakeTrigger()

  const release = startCaptureModeStatus({
    documentObject: fakeDocument(),
    windowObject: fakeWindow(),
    element: trigger
  })

  assert.match(trigger.textContent, /Feedback mode/)
  assert.match(trigger.textContent, /click an element/)
  assert.equal(trigger.classList.contains("page-feedback-widget__trigger--active"), true)
  assert.equal(trigger.getAttribute("aria-pressed"), "true")

  release()

  assert.equal(trigger.textContent, "Give page feedback")
  assert.equal(trigger.classList.contains("page-feedback-widget__trigger--active"), false)
  assert.equal(trigger.getAttribute("aria-pressed"), "false")
})

test("the trigger mode bar tells coarse pointers they can tap it to exit", () => {
  const trigger = fakeTrigger()

  startCaptureModeStatus({
    documentObject: fakeDocument(),
    windowObject: fakeWindow({ coarse: true }),
    element: trigger
  })

  assert.match(trigger.textContent, /tap an element/)
  assert.match(trigger.textContent, /tap here to exit/)
})

test("a hidden trigger falls back to a floating indicator", () => {
  const documentObject = fakeDocument()

  const release = startCaptureModeStatus({ documentObject, windowObject: fakeWindow({ coarse: true }) })
  const [indicator] = documentObject.body.children

  assert.equal(indicator.className, "page-feedback-mode-indicator")
  assert.match(indicator.textContent, /tap an element/)
  assert.doesNotMatch(indicator.textContent, /tap here/)

  release()

  assert.equal(indicator.removed, true)
})
