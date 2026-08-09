const EDITABLE_TAGS = new Set(["INPUT", "TEXTAREA", "SELECT"])

export function keyboardIntent(event, {
  shortcut = { alt: true, key: "f" },
  activeTag,
  modalOpen = false,
  inCommentField = false
} = {}) {
  if (inCommentField && event.key === "Enter" && event.ctrlKey) return "submit"
  if (event.key === "Escape") return modalOpen ? "close-modal" : "stop-picker"
  if (EDITABLE_TAGS.has(activeTag)) return null

  const modifierMatches = ["alt", "ctrl", "meta", "shift"].every((modifier) => {
    const expected = Boolean(shortcut[modifier])
    return Boolean(event[`${modifier}Key`]) === expected
  })
  if (modifierMatches && event.key.toLowerCase() === String(shortcut.key).toLowerCase()) {
    return "toggle-picker"
  }

  return null
}

export function populateCaptureTargets(targets, { capture, context, page, controllerAction, pointerType }) {
  const values = {
    pagePath: page.path,
    pageTitle: page.title,
    cssSelector: capture.selector,
    elementHtml: capture.elementHtml,
    controllerAction,
    parentHtml: context.parentHtml,
    viewport: context.viewport,
    scrollY: context.scrollY,
    consoleErrors: context.consoleErrors,
    navigationHistory: context.navigationHistory,
    pointerType,
    devicePixelRatio: context.devicePixelRatio,
    orientation: context.orientation
  }

  Object.entries(values).forEach(([name, value]) => {
    targets[name].value = value
  })
}
