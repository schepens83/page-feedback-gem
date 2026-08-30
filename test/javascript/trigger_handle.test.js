import assert from "node:assert/strict"
import test from "node:test"

import { startTriggerHandle } from "../../app/assets/javascripts/page_feedback/trigger_handle.js"

const HANDLE_CLASS = "page-feedback-widget__trigger--handle"

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
    classList: classList(),
    setAttribute: (name, value) => attributes.set(name, value),
    removeAttribute: (name) => attributes.delete(name),
    getAttribute: (name) => (attributes.has(name) ? attributes.get(name) : null),
    contains: (node) => node === "inside-the-trigger"
  }
}

function harness({ coarse = true } = {}) {
  const listeners = new Map()
  const timers = new Map()
  let nextTimer = 0

  return {
    listeners,
    timers,
    documentObject: {
      addEventListener: (name, callback) => listeners.set(name, callback),
      removeEventListener: (name) => listeners.delete(name)
    },
    windowObject: {
      matchMedia: () => ({ matches: coarse }),
      setTimeout: (callback) => {
        nextTimer += 1
        timers.set(nextTimer, callback)
        return nextTimer
      },
      clearTimeout: (id) => timers.delete(id)
    },
    dispatch(name, event) { listeners.get(name)?.(event) },
    elapse() {
      const pending = [...timers.values()]
      timers.clear()
      pending.forEach((callback) => callback())
    }
  }
}

function startHandle(options = {}) {
  const context = harness(options)
  const element = fakeTrigger()
  const handle = startTriggerHandle({
    element,
    documentObject: context.documentObject,
    windowObject: context.windowObject
  })
  return { ...context, element, handle }
}

test("a fine pointer keeps the whole trigger on the page", () => {
  const { element, handle, listeners } = startHandle({ coarse: false })

  assert.equal(handle.collapsed, false)
  assert.equal(element.classList.contains(HANDLE_CLASS), false)
  assert.equal(element.getAttribute("aria-expanded"), null)
  assert.equal(listeners.size, 0)
})

test("a coarse pointer parks the trigger as an edge handle", () => {
  const { element, handle } = startHandle()

  assert.equal(handle.collapsed, true)
  assert.equal(element.classList.contains(HANDLE_CLASS), true)
  assert.equal(element.getAttribute("aria-expanded"), "false")
})

test("peeking pulls the trigger out without arming capture", () => {
  const { element, handle, timers } = startHandle()

  handle.expand()

  assert.equal(handle.collapsed, false)
  assert.equal(element.classList.contains(HANDLE_CLASS), false)
  assert.equal(element.getAttribute("aria-expanded"), "true")
  assert.equal(timers.size, 1)
})

test("a peeked trigger parks itself again when it is left alone", () => {
  const { element, handle, elapse } = startHandle()

  handle.expand()
  elapse()

  assert.equal(handle.collapsed, true)
  assert.equal(element.classList.contains(HANDLE_CLASS), true)
})

test("a tap somewhere else parks the peeked trigger, a tap on it does not", () => {
  const { handle, dispatch } = startHandle()

  handle.expand()
  dispatch("pointerdown", { target: "inside-the-trigger" })

  assert.equal(handle.collapsed, false)

  dispatch("pointerdown", { target: "elsewhere" })

  assert.equal(handle.collapsed, true)
})

test("an armed trigger stays out until capture stops", () => {
  const { handle, dispatch, elapse, timers } = startHandle()

  handle.expand({ sticky: true })

  assert.equal(timers.size, 0)

  elapse()
  dispatch("pointerdown", { target: "elsewhere" })

  assert.equal(handle.collapsed, false)

  handle.collapse()

  assert.equal(handle.collapsed, true)
})

test("peeking again after arming restores the idle timer", () => {
  const { handle, elapse } = startHandle()

  handle.expand({ sticky: true })
  handle.collapse()
  handle.expand()
  elapse()

  assert.equal(handle.collapsed, true)
})

test("releasing restores the trigger and drops its listeners", () => {
  const { element, handle, listeners, timers } = startHandle()

  handle.expand()
  handle.release()

  assert.equal(element.classList.contains(HANDLE_CLASS), false)
  assert.equal(element.getAttribute("aria-expanded"), null)
  assert.equal(listeners.size, 0)
  assert.equal(timers.size, 0)
})
