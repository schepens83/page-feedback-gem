import assert from "node:assert/strict"
import test from "node:test"

import { copyText } from "../../app/assets/javascripts/page_feedback/clipboard.js"

test("copyText uses the asynchronous clipboard when available", async () => {
  let copied
  const clipboard = { writeText: async (text) => { copied = text } }

  assert.equal(await copyText("stored body", { clipboard }), true)
  assert.equal(copied, "stored body")
})

test("copyText falls back after clipboard rejection", async () => {
  const textarea = {
    setAttribute() {}, style: {}, select() { this.selected = true }, remove() { this.removed = true }
  }
  const documentObject = {
    body: { appendChild() {} },
    createElement: () => textarea,
    execCommand: () => true
  }
  const clipboard = { writeText: async () => { throw new Error("denied") } }

  assert.equal(await copyText("stored body", { clipboard, documentObject }), true)
  assert.equal(textarea.value, "stored body")
  assert.equal(textarea.removed, true)
})

test("copyText reports failure when both browser paths fail", async () => {
  const clipboard = { writeText: async () => { throw new Error("denied") } }
  const documentObject = { createElement: () => { throw new Error("blocked") } }

  assert.equal(await copyText("stored body", { clipboard, documentObject }), false)
})
