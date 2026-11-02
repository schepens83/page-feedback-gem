import assert from "node:assert/strict"
import test from "node:test"
import { deflateRawSync } from "node:zlib"

import { parseFragment, unpack } from "../../app/assets/javascripts/page_feedback/handoff.js"

function memoryStorage() {
  const data = new Map()
  return {
    getItem: (key) => (data.has(key) ? data.get(key) : null),
    setItem: (key, value) => data.set(key, value),
    removeItem: (key) => data.delete(key),
    size: () => data.size
  }
}

function fragments(text, parts) {
  const payload = deflateRawSync(Buffer.from(text, "utf8")).toString("base64url")
  const size = Math.ceil(payload.length / parts)
  return Array.from({ length: parts }, (_, i) =>
    `#pf1.0123abcd.${i + 1}.${parts}.${payload.slice(i * size, (i + 1) * size)}`)
}

test("parseFragment accepts the pf1 format and rejects anything else", () => {
  assert.deepEqual(parseFragment("#pf1.0123abcd.2.3.abc_-"), { id: "0123abcd", index: 2, total: 3, chunk: "abc_-" })
  assert.equal(parseFragment("#pf1.0123abcd.4.3.abc"), null)
  assert.equal(parseFragment("#pf1.0123abcd.0.3.abc"), null)
  assert.equal(parseFragment("#<script>"), null)
})

test("unpack inflates a single-code export", async () => {
  const [hash] = fragments("# Feedback — één ✓", 1)

  assert.deepEqual(await unpack(hash, memoryStorage()),
    { state: "complete", received: 1, total: 1, text: "# Feedback — één ✓" })
})

test("unpack collects parts in any order across scans and then forgets them", async () => {
  const text = Array.from({ length: 50 }, (_, i) => `- item ${i}`).join("\n")
  const [first, second, third] = fragments(text, 3)
  const storage = memoryStorage()

  assert.deepEqual(await unpack(third, storage), { state: "partial", received: 1, total: 3 })
  assert.deepEqual(await unpack(first, storage), { state: "partial", received: 2, total: 3 })
  assert.equal((await unpack(second, storage)).text, text)
  assert.equal(storage.size(), 0)
})

test("unpack reports empty and unreadable links", async () => {
  assert.equal((await unpack("", memoryStorage())).state, "empty")
  assert.equal((await unpack("#nonsense", memoryStorage())).state, "invalid")
  assert.equal((await unpack("#pf1.0123abcd.1.1.AAAA", memoryStorage())).state, "invalid")
})

test("unpack still handles a single code without storage", async () => {
  const [hash] = fragments("no storage", 1)
  assert.equal((await unpack(hash, null)).text, "no storage")
})
