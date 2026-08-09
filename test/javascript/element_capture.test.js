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

test("shouldSkipElement rejects only PageFeedback engine chrome", () => {
  const body = element("BODY")
  const chrome = element("DIV", { classes: ["page-feedback-modal"], parent: body })
  const chromeChild = element("SPAN", { parent: chrome })
  const ordinary = element("ARTICLE", { parent: body })

  assert.equal(shouldSkipElement(chromeChild, { root: body }), true)
  assert.equal(shouldSkipElement(ordinary, { root: body }), false)
})

test("shouldSkipElement now accepts interactive host elements", () => {
  const body = element("BODY")
  const nav = element("NAV", { parent: body })
  const link = element("A", { parent: nav })
  const form = element("FORM", { parent: body })
  const input = element("INPUT", { parent: form })
  const button = element("BUTTON", { parent: body })

  assert.equal(shouldSkipElement(link, { root: body }), false)
  assert.equal(shouldSkipElement(input, { root: body }), false)
  assert.equal(shouldSkipElement(button, { root: body }), false)
})
