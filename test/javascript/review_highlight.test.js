import assert from "node:assert/strict"
import test from "node:test"

import {
  applyReviewHighlight,
  sanitizeReplaySelector
} from "../../app/assets/javascripts/page_feedback/review_highlight.js"

test("sanitizeReplaySelector strips configured runtime classes", () => {
  assert.equal(
    sanitizeReplaySelector("#case > p.copy.revealed.volatile", ["revealed", "volatile"]),
    "#case > p.copy"
  )
})

test("applyReviewHighlight tolerates missing and invalid selectors", () => {
  const missingDocument = { querySelector: () => null }
  const invalidDocument = { querySelector: () => { throw new SyntaxError("bad selector") } }
  const windowObject = { scrollTo() {} }

  assert.equal(applyReviewHighlight({ selector: ".missing", documentObject: missingDocument, windowObject }), false)
  assert.equal(applyReviewHighlight({ selector: "[", documentObject: invalidDocument, windowObject }), false)
})

test("applyReviewHighlight marks and scrolls the matched element", () => {
  const classes = []
  const target = {
    classList: { add: (name) => classes.push(name) },
    scrollIntoViewOptions: null,
    scrollIntoView(options) { this.scrollIntoViewOptions = options }
  }
  const documentObject = { querySelector: () => target }

  assert.equal(applyReviewHighlight({ selector: "#target", documentObject, windowObject: {} }), true)
  assert.deepEqual(classes, ["page-feedback-review-highlight"])
  assert.equal(target.scrollIntoViewOptions.block, "center")
})
