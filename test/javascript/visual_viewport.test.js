import assert from "node:assert/strict"
import test from "node:test"

import { trackVisualViewport } from "../../app/assets/javascripts/page_feedback/visual_viewport.js"

function createElement() {
  const properties = new Map()
  return {
    properties,
    style: {
      setProperty: (name, value) => properties.set(name, value),
      removeProperty: (name) => properties.delete(name)
    }
  }
}

function createWindow({ layoutHeight, height, offsetTop = 0 }) {
  const listeners = new Map()
  return {
    listeners,
    document: { documentElement: { clientHeight: layoutHeight } },
    visualViewport: {
      height,
      offsetTop,
      addEventListener: (name, callback) => listeners.set(name, callback),
      removeEventListener: (name) => listeners.delete(name)
    }
  }
}

test("visual viewport tracking reports the height and hidden bottom strip", () => {
  const element = createElement()
  const windowObject = createWindow({ layoutHeight: 800, height: 360, offsetTop: 40 })

  const release = trackVisualViewport(element, windowObject)

  assert.equal(element.properties.get("--page-feedback-visual-viewport-height"), "360px")
  assert.equal(element.properties.get("--page-feedback-visual-viewport-offset-bottom"), "400px")

  windowObject.visualViewport.height = 800
  windowObject.visualViewport.offsetTop = 0
  windowObject.listeners.get("resize")()

  assert.equal(element.properties.get("--page-feedback-visual-viewport-height"), "800px")
  assert.equal(element.properties.get("--page-feedback-visual-viewport-offset-bottom"), "0px")

  release()

  assert.equal(windowObject.listeners.size, 0)
  assert.equal(element.properties.size, 0)
})

test("visual viewport tracking never reports a negative bottom strip", () => {
  const element = createElement()
  const windowObject = createWindow({ layoutHeight: 800, height: 812 })

  trackVisualViewport(element, windowObject)

  assert.equal(element.properties.get("--page-feedback-visual-viewport-offset-bottom"), "0px")
})

test("visual viewport tracking is inert without the browser API", () => {
  const element = createElement()

  const release = trackVisualViewport(element, { document: { documentElement: { clientHeight: 800 } } })
  release()

  assert.equal(element.properties.size, 0)
})
