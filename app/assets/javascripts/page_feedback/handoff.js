// Decodes a forward link from another installation (see PageFeedback::ForwardPayload).
// The fragment is `pf2.<base64url of raw-deflated JSON>`; it never reaches a
// server, so the page decodes it here and posts the JSON to the import form.

const FRAGMENT = /^#?pf2\.([A-Za-z0-9_-]+)$/
const FORMAT = "page_feedback.forward"
const VERSION = 1

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

// Returns { state: "empty" | "invalid" | "ready", json, source, comments }.
export async function decodeForward(hash) {
  if (!hash || hash === "#") return { state: "empty" }

  const match = FRAGMENT.exec(hash)
  if (!match) return { state: "invalid" }

  try {
    const json = await inflate(match[1])
    const payload = JSON.parse(json)
    const valid = payload && payload.format === FORMAT && payload.version === VERSION &&
      Array.isArray(payload.comments) && payload.comments.length > 0
    if (!valid) return { state: "invalid" }

    return { state: "ready", json, source: typeof payload.source === "string" ? payload.source : "", comments: payload.comments }
  } catch {
    return { state: "invalid" }
  }
}

// One short preview line per comment, as plain text.
export function previewLine(comment) {
  const text = String(comment?.comment_text ?? "").replace(/\s+/g, " ").trim()
  const short = text.length > 140 ? `${text.slice(0, 139)}…` : text
  return `${comment?.category ?? "?"} · ${comment?.page_path ?? "?"} — ${short}`
}
