import assert from "node:assert/strict"
import test from "node:test"

import { createContextRecorder } from "../../app/assets/javascripts/page_feedback/context_recorder.js"

test("context recorder retains only the latest console and navigation entries", () => {
  const calls = []
  const consoleObject = { error: (...args) => calls.push(args) }
  const historyObject = {
    pushState() {},
    replaceState() {}
  }
  const listeners = new Map()
  const windowObject = {
    innerWidth: 1440,
    innerHeight: 900,
    scrollY: 812.4,
    location: { href: "https://example.test/current" },
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: (name) => listeners.delete(name)
  }
  let timestamp = 100
  const recorder = createContextRecorder({
    consoleObject,
    historyObject,
    windowObject,
    now: () => timestamp++
  })

  for (let index = 0; index < 12; index += 1) consoleObject.error("failure", index)
  for (let index = 0; index < 7; index += 1) historyObject.pushState({}, "", `/pages/${index}`)

  const context = recorder.capturePageContext("<main>context</main>")
  const errors = JSON.parse(context.consoleErrors)
  const navigation = JSON.parse(context.navigationHistory)

  assert.equal(calls.length, 12)
  assert.equal(errors.length, 10)
  assert.equal(errors[0].message, "failure 2")
  assert.equal(navigation.length, 5)
  assert.equal(navigation[0].url, "/pages/2")
  assert.equal(context.viewport, "1440x900")
  assert.equal(context.scrollY, 812)

  recorder.disconnect()
})
