const CLICK_BLOCKER_LINGER_MS = 400
const TAP_MOVE_TOLERANCE_PX = 10
const PROMOTABLE_SELECTOR = "a, button, input, select, textarea, label, summary, [role='button']"

function createButton(documentObject, label, modifierClass) {
  const button = documentObject.createElement("button")
  button.type = "button"
  button.className = `page-feedback-button ${modifierClass}`
  button.textContent = label
  return button
}

function isCoarsePointer(windowObject) {
  return Boolean(windowObject.matchMedia?.("(pointer: coarse)")?.matches)
}

// Mouse hover/click picks immediately. Touch and pen taps only stage a
// candidate: the confirm bar lets the user add feedback, walk up to a
// semantic ancestor, or cancel, without losing native scroll/zoom gestures.
export function startFeedbackPicker({
  documentObject = document,
  windowObject = window,
  shouldSkip,
  onPick
} = {}) {
  const indicator = documentObject.createElement("div")
  indicator.className = "page-feedback-mode-indicator"
  indicator.textContent = isCoarsePointer(windowObject)
    ? "Feedback mode — tap an element · tap the feedback button to exit"
    : "Feedback mode — click an element · Alt+F or Escape to exit"

  const overlay = documentObject.createElement("div")
  overlay.className = "page-feedback-capture-overlay"
  overlay.hidden = true

  const confirmLabel = documentObject.createElement("span")
  confirmLabel.className = "page-feedback-confirm-bar__label"

  const addButton = createButton(documentObject, "Add feedback", "page-feedback-confirm-bar__add")
  const parentButton = createButton(documentObject, "Choose parent", "page-feedback-confirm-bar__parent")
  const cancelButton = createButton(documentObject, "Cancel", "page-feedback-confirm-bar__cancel")

  const confirmBar = documentObject.createElement("div")
  confirmBar.className = "page-feedback-confirm-bar"
  confirmBar.hidden = true
  confirmBar.appendChild(confirmLabel)
  confirmBar.appendChild(addButton)
  confirmBar.appendChild(parentButton)
  confirmBar.appendChild(cancelButton)

  documentObject.body.classList.add("page-feedback-capture-mode")
  documentObject.body.appendChild(indicator)
  documentObject.body.appendChild(overlay)
  documentObject.body.appendChild(confirmBar)

  let pending
  let candidate
  let candidatePointerType
  let overlayTarget
  let tornDown = false
  let clickBlockerActive = true
  let clickBlockerLingering = false

  const repositionOverlay = (target) => {
    const rect = target.getBoundingClientRect()
    overlay.style.top = `${rect.top}px`
    overlay.style.left = `${rect.left}px`
    overlay.style.width = `${rect.width}px`
    overlay.style.height = `${rect.height}px`
  }
  const showOverlayOn = (target) => {
    overlayTarget = target
    overlay.hidden = false
    repositionOverlay(target)
  }
  const hideOverlay = () => {
    overlayTarget = undefined
    overlay.hidden = true
  }
  const showConfirmBarFor = (target) => {
    confirmLabel.textContent = `Feedback on <${target.tagName.toLowerCase()}>`
    confirmBar.hidden = false
  }
  const hideConfirmBar = () => {
    confirmBar.hidden = true
  }
  const setCandidate = (target, pointerType) => {
    candidate = target
    candidatePointerType = pointerType
    showOverlayOn(target)
    showConfirmBarFor(target)
  }
  const clearCandidate = () => {
    candidate = undefined
    candidatePointerType = undefined
    hideOverlay()
    hideConfirmBar()
  }

  const onReposition = () => {
    if (overlayTarget) repositionOverlay(overlayTarget)
  }
  const onPointerOver = (event) => {
    if (event.pointerType !== "mouse") return
    if (shouldSkip(event.target)) {
      hideOverlay()
      return
    }
    showOverlayOn(event.target)
  }
  const onPointerDown = (event) => {
    if (pending && event.pointerId !== pending.pointerId) {
      pending = undefined
      return
    }
    if (!event.isPrimary || event.button !== 0) return
    if (shouldSkip(event.target)) return

    pending = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, target: event.target }
  }
  const onPointerMove = (event) => {
    if (!pending || event.pointerId !== pending.pointerId) return

    const dx = event.clientX - pending.x
    const dy = event.clientY - pending.y
    if (Math.hypot(dx, dy) > TAP_MOVE_TOLERANCE_PX) pending = undefined
  }
  const onPointerCancel = () => {
    pending = undefined
  }
  const onPointerUp = (event) => {
    if (!pending || event.pointerId !== pending.pointerId) return

    const target = pending.target
    pending = undefined
    if (shouldSkip(target)) return

    if (event.pointerType === "mouse") {
      event.preventDefault()
      event.stopPropagation()
      finish(target, "mouse")
      return
    }

    event.preventDefault()
    event.stopPropagation()
    const promoted = target.closest?.(PROMOTABLE_SELECTOR)
    const promotable = promoted && !shouldSkip(promoted) ? promoted : target
    setCandidate(promotable, event.pointerType)
  }

  const removeClickBlocker = () => {
    if (!clickBlockerActive) return
    clickBlockerActive = false
    documentObject.removeEventListener("click", onClick, true)
  }
  const onClick = (event) => {
    if (shouldSkip(event.target)) return

    event.preventDefault()
    event.stopPropagation()
    if (clickBlockerLingering) removeClickBlocker()
  }

  const addChromeListeners = () => {
    documentObject.addEventListener("pointerover", onPointerOver)
    documentObject.addEventListener("pointerdown", onPointerDown, true)
    documentObject.addEventListener("pointerup", onPointerUp, true)
    documentObject.addEventListener("pointermove", onPointerMove)
    documentObject.addEventListener("pointercancel", onPointerCancel)
    documentObject.addEventListener("click", onClick, true)
    windowObject.addEventListener("scroll", onReposition, { capture: true, passive: true })
    windowObject.addEventListener("resize", onReposition)
  }
  const removeChromeListeners = () => {
    documentObject.removeEventListener("pointerover", onPointerOver)
    documentObject.removeEventListener("pointerdown", onPointerDown, true)
    documentObject.removeEventListener("pointerup", onPointerUp, true)
    documentObject.removeEventListener("pointermove", onPointerMove)
    documentObject.removeEventListener("pointercancel", onPointerCancel)
    windowObject.removeEventListener("scroll", onReposition, { capture: true, passive: true })
    windowObject.removeEventListener("resize", onReposition)
  }

  addButton.addEventListener("click", () => {
    if (candidate) finish(candidate, candidatePointerType)
  })
  parentButton.addEventListener("click", () => {
    if (!candidate) return
    const parent = candidate.parentElement
    if (!parent || parent === documentObject.body) return

    setCandidate(parent, candidatePointerType)
  })
  cancelButton.addEventListener("click", () => {
    clearCandidate()
  })

  function teardown() {
    if (tornDown) return
    tornDown = true

    documentObject.body.classList.remove("page-feedback-capture-mode")
    indicator.remove()
    overlay.remove()
    confirmBar.remove()
    removeChromeListeners()

    // The pointerup that just selected an element is followed by a browser
    // click on the same target; keep blocking one more click so it does not
    // reach the host page, then uninstall — with a timeout fallback in case
    // no click ever arrives (e.g. Escape/Alt+F cancellation).
    clickBlockerLingering = true
    windowObject.setTimeout?.(removeClickBlocker, CLICK_BLOCKER_LINGER_MS)
  }

  function finish(element, pointerType) {
    teardown()
    onPick(element, { pointerType })
  }

  function stop() {
    teardown()
  }

  addChromeListeners()
  return stop
}
