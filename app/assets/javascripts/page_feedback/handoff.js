// Reassembles an export handed over as QR codes (see PageFeedback::Handoff).
// Each code is a link whose fragment is `pf1.<id>.<index>.<total>.<chunk>`;
// chunks are pieces of one base64url, raw-deflated payload. Parts arrive one
// scan at a time, often in separate tabs, so they wait in localStorage.

const FRAGMENT = /^#?pf1\.([0-9a-f]{8})\.(\d{1,2})\.(\d{1,2})\.([A-Za-z0-9_-]+)$/
const PREFIX = "page-feedback-handoff:"

export function parseFragment(hash) {
  const match = FRAGMENT.exec(hash || "")
  if (!match) return null

  const [, id, index, total, chunk] = match
  const part = { id, index: Number(index), total: Number(total), chunk }
  return part.index >= 1 && part.index <= part.total ? part : null
}

function readParts(storage, key, total) {
  try {
    const stored = JSON.parse(storage?.getItem(key) || "null")
    if (Array.isArray(stored) && stored.length === total) return stored
  } catch {
    // Unavailable or corrupt storage: start this export afresh.
  }
  return Array(total).fill(null)
}

function writeParts(storage, key, parts) {
  try {
    if (parts.every(Boolean)) storage?.removeItem(key)
    else storage?.setItem(key, JSON.stringify(parts))
  } catch {
    // Without storage only single-code exports can be unpacked.
  }
}

export function base64UrlToBytes(text) {
  const base64 = text.replace(/-/g, "+").replace(/_/g, "/")
  const binary = atob(base64 + "=".repeat((4 - (base64.length % 4)) % 4))
  return Uint8Array.from(binary, (character) => character.charCodeAt(0))
}

export async function inflate(payload) {
  const stream = new Blob([base64UrlToBytes(payload)]).stream()
    .pipeThrough(new DecompressionStream("deflate-raw"))
  return new Response(stream).text()
}

// Returns { state: "empty" | "invalid" | "partial" | "complete", received, total, text }.
export async function unpack(hash, storage) {
  if (!hash || hash === "#") return { state: "empty" }

  const part = parseFragment(hash)
  if (!part) return { state: "invalid" }

  const key = `${PREFIX}${part.id}:${part.total}`
  const parts = readParts(storage, key, part.total)
  parts[part.index - 1] = part.chunk
  writeParts(storage, key, parts)

  const received = parts.filter(Boolean).length
  if (received < part.total) return { state: "partial", received, total: part.total }

  try {
    return { state: "complete", received, total: part.total, text: await inflate(parts.join("")) }
  } catch {
    return { state: "invalid" }
  }
}
