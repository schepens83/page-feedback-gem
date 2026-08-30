const HANDLE_CLASS = "page-feedback-widget__trigger--handle"
const PEEK_LINGER_MS = 5_000

// A permanent floating button is a heavy thing to leave on a phone screen, and
// touch has no keyboard shortcut to fall back on. So on coarse pointers the
// trigger parks itself against the viewport edge with only a sliver showing:
// the first tap pulls it out, the second arms capture. Fine pointers keep the
// whole button, because they already have both the room and the shortcut.
export function startTriggerHandle({
  element,
  documentObject = document,
  windowObject = window,
  lingerMs = PEEK_LINGER_MS
} = {}) {
  if (!element || !windowObject.matchMedia?.("(pointer: coarse)")?.matches) {
    return { collapsed: false, expand() {}, collapse() {}, release() {} }
  }

  let collapsed = false
  let sticky = false
  let lingerTimer

  const cancelLinger = () => {
    if (lingerTimer === undefined) return

    windowObject.clearTimeout(lingerTimer)
    lingerTimer = undefined
  }
  const collapse = () => {
    cancelLinger()
    sticky = false
    collapsed = true
    element.classList.add(HANDLE_CLASS)
    element.setAttribute("aria-expanded", "false")
  }
  const expand = ({ sticky: stayOut = false } = {}) => {
    cancelLinger()
    sticky = stayOut
    collapsed = false
    element.classList.remove(HANDLE_CLASS)
    element.setAttribute("aria-expanded", "true")
    // Armed capture owns the trigger as its mode bar, so only an idle peek
    // times out.
    if (!sticky) lingerTimer = windowObject.setTimeout(collapse, lingerMs)
  }
  // A tap on the trigger is the one that arms capture; anything else is the
  // user getting on with the page, and the handle gets out of the way.
  const handlePointerDown = (event) => {
    if (collapsed || sticky || element.contains(event.target)) return

    collapse()
  }

  collapse()
  documentObject.addEventListener("pointerdown", handlePointerDown, true)

  return {
    get collapsed() { return collapsed },
    expand,
    collapse,
    release() {
      cancelLinger()
      documentObject.removeEventListener("pointerdown", handlePointerDown, true)
      element.classList.remove(HANDLE_CLASS)
      element.removeAttribute("aria-expanded")
    }
  }
}
