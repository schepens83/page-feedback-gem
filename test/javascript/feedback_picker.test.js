import assert from "node:assert/strict"
import test from "node:test"

import { startFeedbackPicker } from "../../app/assets/javascripts/page_feedback/feedback_picker.js"

function classList() {
  const names = new Set()
  return {
    add: (name) => names.add(name),
    contains: (name) => names.has(name),
    remove: (name) => names.delete(name)
  }
}

test("feedback picker highlights and intercepts an ordinary element click", () => {
  const listeners = new Map()
  const indicator = { className: "", textContent: "", remove() { this.removed = true } }
  const body = { classList: classList(), appendChild: (element) => { element.appended = true } }
  const documentObject = {
    body,
    createElement: () => indicator,
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: (name) => listeners.delete(name)
  }
  const target = { classList: classList() }
  let selected
  let prevented = false
  let stopped = false

  startFeedbackPicker({
    documentObject,
    shouldSkip: () => false,
    onPick: (element) => { selected = element }
  })

  listeners.get("mouseover")({ target })
  listeners.get("click")({
    target,
    preventDefault: () => { prevented = true },
    stopPropagation: () => { stopped = true }
  })

  assert.equal(target.classList.contains("page-feedback-capture-highlight"), false)
  assert.equal(body.classList.contains("page-feedback-capture-mode"), false)
  assert.equal(indicator.removed, true)
  assert.equal(prevented, true)
  assert.equal(stopped, true)
  assert.equal(selected, target)
})

test("feedback picker selects on a primary pointer press before host click handlers", () => {
  const listeners = new Map()
  const indicator = { className: "", textContent: "", remove() {} }
  const body = { classList: classList(), appendChild() {} }
  const documentObject = {
    body,
    createElement: () => indicator,
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: (name) => listeners.delete(name)
  }
  const target = { classList: classList() }
  let selected

  startFeedbackPicker({
    documentObject,
    shouldSkip: () => false,
    onPick: (element) => { selected = element }
  })

  let prevented = false
  let stopped = false
  listeners.get("pointerdown")({
    button: 0,
    target,
    preventDefault: () => { prevented = true },
    stopPropagation: () => { stopped = true }
  })

  assert.equal(selected, target)
  assert.equal(prevented, true)
  assert.equal(stopped, true)
  assert.equal(body.classList.contains("page-feedback-capture-mode"), false)
})
