import assert from "node:assert/strict"
import test from "node:test"

import {
  applyReviewHighlight,
  installReviewHighlight,
  replaySelectorCandidates,
  sanitizeReplaySelector
} from "../../app/assets/javascripts/page_feedback/review_highlight.js"

function fakeTarget() {
  const classes = []
  return {
    classes,
    classList: { add: (name) => classes.push(name) },
    scrollIntoViewOptions: null,
    scrollIntoView(options) { this.scrollIntoViewOptions = options }
  }
}

function fakeDocument({ matches = {}, ignoredClasses = "" } = {}) {
  return {
    readyState: "complete",
    documentElement: { tagName: "HTML" },
    querySelector(selector) {
      if (selector.startsWith("meta")) return ignoredClasses ? { content: ignoredClasses } : null

      return matches[selector] || null
    }
  }
}

function fakeWindow() {
  const observers = []
  const timeouts = []
  return {
    observers,
    timeouts,
    scrolledTo: null,
    scrollTo(options) { this.scrolledTo = options },
    setTimeout(callback) { timeouts.push(callback); return timeouts.length },
    clearTimeout() {},
    MutationObserver: class {
      constructor(callback) {
        this.callback = callback
        observers.push(this)
      }

      observe(node, options) {
        this.observed = { node, options }
      }

      disconnect() {
        this.disconnected = true
      }
    }
  }
}

test("sanitizeReplaySelector strips configured runtime classes", () => {
  assert.equal(
    sanitizeReplaySelector("#case > p.copy.revealed.volatile", ["revealed", "volatile"]),
    "#case > p.copy"
  )
})

test("replaySelectorCandidates falls back to a class-free path", () => {
  assert.deepEqual(
    replaySelectorCandidates("#case > div.card.revealed > p.copy:nth-child(2)", ["revealed"]),
    ["#case > div.card > p.copy:nth-child(2)", "#case > div > p:nth-child(2)"]
  )
})

test("replaySelectorCandidates keeps escaped class characters intact and dedupes", () => {
  assert.deepEqual(replaySelectorCandidates("main > section:nth-child(3)"), ["main > section:nth-child(3)"])
  assert.deepEqual(
    replaySelectorCandidates("div.md\\:flex > span"),
    ["div.md\\:flex > span", "div > span"]
  )
})

test("applyReviewHighlight tolerates missing and invalid selectors", () => {
  const invalidDocument = {
    querySelector: () => { throw new SyntaxError("bad selector") }
  }

  assert.equal(applyReviewHighlight({ selector: ".missing", documentObject: fakeDocument() }), false)
  assert.equal(applyReviewHighlight({ selector: "[", documentObject: invalidDocument }), false)
})

test("applyReviewHighlight marks and centers the matched element", () => {
  const target = fakeTarget()
  const documentObject = fakeDocument({ matches: { "#target": target } })

  assert.equal(applyReviewHighlight({ selector: "#target", documentObject }), true)
  assert.deepEqual(target.classes, ["page-feedback-review-highlight"])
  assert.equal(target.scrollIntoViewOptions.block, "center")
})

test("applyReviewHighlight matches a drifted element through the class-free fallback", () => {
  const target = fakeTarget()
  const documentObject = fakeDocument({ matches: { "main > p:nth-child(2)": target } })

  assert.equal(applyReviewHighlight({ selector: "main > p.copy:nth-child(2)", documentObject }), true)
  assert.deepEqual(target.classes, ["page-feedback-review-highlight"])
})

test("the replay centers the element instead of restoring the captured scroll offset", () => {
  const target = fakeTarget()
  const documentObject = fakeDocument({ matches: { "#target": target } })
  const windowObject = fakeWindow()

  installReviewHighlight({
    documentObject,
    windowObject,
    locationObject: { search: "?page_feedback_selector=%23target&page_feedback_scroll=900" }
  })

  assert.equal(target.scrollIntoViewOptions.block, "center")
  assert.equal(windowObject.scrolledTo, null, "the captured offset belongs to a different viewport width")
})

test("the replay keeps watching until a late-rendered element appears", () => {
  const target = fakeTarget()
  const matches = {}
  const documentObject = fakeDocument({ matches })
  const windowObject = fakeWindow()

  installReviewHighlight({
    documentObject,
    windowObject,
    locationObject: { search: "?page_feedback_selector=%23late&page_feedback_scroll=640" }
  })
  const [observer] = windowObject.observers

  assert.equal(windowObject.scrolledTo.top, 560, "an unmatched element still lands the reviewer nearby")
  assert.equal(observer.observed.options.subtree, true)

  matches["#late"] = target
  observer.callback()

  assert.deepEqual(target.classes, ["page-feedback-review-highlight"])
  assert.equal(observer.disconnected, true)
})

test("the replay stops watching once the match budget expires", () => {
  const documentObject = fakeDocument()
  const windowObject = fakeWindow()

  installReviewHighlight({
    documentObject,
    windowObject,
    locationObject: { search: "?page_feedback_selector=%23never" }
  })
  const [observer] = windowObject.observers
  windowObject.timeouts.forEach((callback) => callback())

  assert.equal(observer.disconnected, true)
})

test("the replay honors host-configured runtime classes from the page head", () => {
  const target = fakeTarget()
  const documentObject = fakeDocument({
    matches: { "main > p.copy": target },
    ignoredClasses: "revealed scene-visible"
  })

  installReviewHighlight({
    documentObject,
    windowObject: fakeWindow(),
    locationObject: { search: "?page_feedback_selector=main%20%3E%20p.copy.revealed" }
  })

  assert.deepEqual(target.classes, ["page-feedback-review-highlight"])
})
