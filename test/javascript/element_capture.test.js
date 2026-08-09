import assert from "node:assert/strict"
import test from "node:test"

import {
  buildSelector,
  captureElement,
  shouldSkipElement
} from "../../app/assets/javascripts/page_feedback/element_capture.js"

function element(tagName, { id = "", classes = [], html = "", parent = null } = {}) {
  const node = {
    tagName,
    id,
    classList: classes,
    outerHTML: html,
    parentElement: parent,
    children: []
  }
  node.classList.contains = (name) => node.classList.includes(name)
  if (parent) parent.children.push(node)
  return node
}

test("buildSelector excludes configured runtime classes and anchors at an id", () => {
  const body = element("BODY")
  const section = element("SECTION", { id: "case", parent: body })
  const target = element("P", { classes: ["copy", "revealed", "volatile"], parent: section })

  assert.equal(
    buildSelector(target, { root: body, ignoredClasses: ["revealed", "volatile"] }),
    "#case > p.copy"
  )
})

test("buildSelector distinguishes same-tag siblings", () => {
  const body = element("BODY")
  const section = element("SECTION", { parent: body })
  element("P", { parent: section })
  const target = element("P", { parent: section })

  assert.equal(buildSelector(target, { root: body }), "section > p:nth-child(2)")
})

test("captureElement caps selected and parent HTML", () => {
  const body = element("BODY")
  const parent = element("SECTION", { html: "p".repeat(1_200), parent: body })
  const target = element("DIV", { html: "e".repeat(2_200), parent })

  const capture = captureElement(target, { root: body })

  assert.equal(capture.elementHtml.length, 2_000)
  assert.equal(capture.parentHtml.length, 1_000)
})

test("shouldSkipElement rejects controls and PageFeedback chrome", () => {
  const body = element("BODY")
  const form = element("FORM", { parent: body })
  const formChild = element("SPAN", { parent: form })
  const chrome = element("DIV", { classes: ["page-feedback-modal"], parent: body })
  const chromeChild = element("SPAN", { parent: chrome })
  const ordinary = element("ARTICLE", { parent: body })

  assert.equal(shouldSkipElement(formChild, { root: body }), true)
  assert.equal(shouldSkipElement(chromeChild, { root: body }), true)
  assert.equal(shouldSkipElement(ordinary, { root: body }), false)
})

test("shouldSkipElement still accepts an element the picker is highlighting", () => {
  const body = element("BODY")
  const hovered = element("ARTICLE", { classes: ["page-feedback-capture-highlight"], parent: body })
  const hoveredChild = element("SPAN", { classes: ["page-feedback-capture-highlight"], parent: hovered })

  assert.equal(shouldSkipElement(hovered, { root: body }), false)
  assert.equal(shouldSkipElement(hoveredChild, { root: body }), false)
})
