import assert from "node:assert/strict"
import test from "node:test"
import { deflateRawSync } from "node:zlib"

import { decodeForward, previewLine } from "../../app/assets/javascripts/page_feedback/handoff.js"

function fragmentFor(payload) {
  return `#pf2.${deflateRawSync(Buffer.from(JSON.stringify(payload), "utf8")).toString("base64url")}`
}

const comment = {
  uuid: "0f8fad5b-d9cb-469f-a165-70867728950e", category: "idea",
  comment_text: "De weekweergave — één klik te veel", page_path: "/kompas"
}

test("decodeForward returns the posted JSON, source and comments", async () => {
  const payload = { format: "page_feedback.forward", version: 1, source: "Work laptop", comments: [comment] }
  const result = await decodeForward(fragmentFor(payload))

  assert.equal(result.state, "ready")
  assert.equal(result.source, "Work laptop")
  assert.deepEqual(result.comments, [comment])
  assert.deepEqual(JSON.parse(result.json), payload)
})

test("decodeForward reports an empty page and rejects anything else", async () => {
  assert.equal((await decodeForward("")).state, "empty")
  assert.equal((await decodeForward("#nonsense")).state, "invalid")
  assert.equal((await decodeForward("#pf2.AAAA")).state, "invalid")
  assert.equal((await decodeForward(fragmentFor({ format: "other", version: 1, comments: [comment] }))).state, "invalid")
  assert.equal((await decodeForward(fragmentFor({ format: "page_feedback.forward", version: 2, comments: [comment] }))).state, "invalid")
  assert.equal((await decodeForward(fragmentFor({ format: "page_feedback.forward", version: 1, comments: [] }))).state, "invalid")
})

test("previewLine is one short plain-text line", () => {
  const line = previewLine({ ...comment, comment_text: `a\n${"x".repeat(300)}` })

  assert.ok(line.startsWith("idea · /kompas — a x"))
  assert.ok(line.length < 170)
  assert.equal(previewLine({}), "? · ? — ")
})
