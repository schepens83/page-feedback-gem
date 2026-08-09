const ACTIVE_CLASS = "page-feedback-widget__trigger--active"

function isCoarsePointer(windowObject) {
  return Boolean(windowObject.matchMedia?.("(pointer: coarse)")?.matches)
}

function modeLabel(windowObject, { interactive }) {
  if (!isCoarsePointer(windowObject)) return "Feedback mode — click an element · Alt+F or Escape to exit"

  return interactive
    ? "Feedback mode — tap an element · tap here to exit"
    : "Feedback mode — tap an element"
}

// While capture is armed the trigger states the mode and exits it, so a small
// screen keeps one control instead of a button beside a separate banner. Hosts
// that hide the trigger have nothing to convert, and get a floating indicator.
export function startCaptureModeStatus({ documentObject = document, windowObject = window, element } = {}) {
  if (element) {
    const triggerLabel = element.textContent

    element.textContent = modeLabel(windowObject, { interactive: true })
    element.classList.add(ACTIVE_CLASS)
    element.setAttribute("aria-pressed", "true")

    return () => {
      element.textContent = triggerLabel
      element.classList.remove(ACTIVE_CLASS)
      element.setAttribute("aria-pressed", "false")
    }
  }

  const indicator = documentObject.createElement("div")
  indicator.className = "page-feedback-mode-indicator"
  indicator.textContent = modeLabel(windowObject, { interactive: false })
  documentObject.body.appendChild(indicator)

  return () => indicator.remove()
}
