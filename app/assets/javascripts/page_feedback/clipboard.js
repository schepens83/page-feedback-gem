function fallbackCopy(text, documentObject) {
  const textarea = documentObject.createElement("textarea")
  textarea.value = text
  textarea.setAttribute("readonly", "")
  textarea.style.position = "fixed"
  textarea.style.opacity = "0"
  documentObject.body.appendChild(textarea)
  textarea.select()
  const copied = documentObject.execCommand("copy")
  textarea.remove()
  return copied
}

export async function copyText(text, {
  clipboard = globalThis.navigator?.clipboard,
  documentObject = globalThis.document
} = {}) {
  if (clipboard?.writeText) {
    try {
      await clipboard.writeText(text)
      return true
    } catch (_error) {
      // Continue to the browser's synchronous fallback.
    }
  }

  try {
    return fallbackCopy(text, documentObject)
  } catch (_error) {
    return false
  }
}
