// A captured selector describes the DOM as it was when the reviewer's page was
// captured. Replays run later, in a narrower frame, often before client-rendered
// content exists, so matching is a best effort that keeps trying.
const MATCH_BUDGET_MS = 8000
const CLASS_TOKEN = /\.(?:\\.|[^\s.#:>[\\])+/g
const IGNORED_CLASSES_META = 'meta[name="page-feedback-ignored-classes"]'
const SCROLL_LEAD_PX = 80

export function sanitizeReplaySelector(selector, ignoredClasses = []) {
  return ignoredClasses.reduce((value, className) => {
    const escaped = className.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    return value.replace(new RegExp(`\\.${escaped}\\b`, "g"), "")
  }, selector)
}

// Classes are the least stable part of a captured selector: hosts toggle
// animation, state, and utility classes between capture and replay. Dropping
// every class keeps the structural path — tags, ids, and positions — as a
// second chance at the same element.
export function replaySelectorCandidates(selector, ignoredClasses = []) {
  const sanitized = sanitizeReplaySelector(selector, ignoredClasses)
  const structural = sanitized.replace(CLASS_TOKEN, "")

  return [...new Set([sanitized, structural])].filter(isCompleteSelector)
}

function isCompleteSelector(selector) {
  return selector.split(">").every((segment) => segment.trim().length > 0)
}

function findReplayTarget(selector, ignoredClasses, documentObject) {
  for (const candidate of replaySelectorCandidates(selector, ignoredClasses)) {
    try {
      const target = documentObject.querySelector(candidate)
      if (target) return target
    } catch (_error) {
      // An unparseable candidate is no worse than a missing one.
    }
  }

  return undefined
}

export function applyReviewHighlight({ selector, ignoredClasses, documentObject = document }) {
  const target = findReplayTarget(selector, ignoredClasses, documentObject)
  if (!target) return false

  target.classList.add("page-feedback-review-highlight")
  // The captured scroll offset belongs to the reviewer's original viewport;
  // in the review frame only the element itself knows where it is.
  target.scrollIntoView({ block: "center", behavior: "instant" })
  return true
}

function configuredIgnoredClasses(documentObject) {
  const meta = documentObject.querySelector?.(IGNORED_CLASSES_META)

  return (meta?.content || "").split(/\s+/).filter(Boolean)
}

function restoreCapturedScroll(scrollY, windowObject) {
  if (!(scrollY > 0) || !windowObject.scrollTo) return

  windowObject.scrollTo({ top: Math.max(0, scrollY - SCROLL_LEAD_PX), behavior: "instant" })
}

export function installReviewHighlight({
  documentObject = document,
  windowObject = window,
  locationObject = location
} = {}) {
  const parameters = new URLSearchParams(locationObject.search)
  const selector = parameters.get("page_feedback_selector")
  if (!selector) return

  const ignoredClasses = configuredIgnoredClasses(documentObject)
  const apply = () => applyReviewHighlight({ selector, ignoredClasses, documentObject })

  const start = () => {
    if (apply()) return

    restoreCapturedScroll(Number.parseInt(parameters.get("page_feedback_scroll") || "0", 10), windowObject)
    watchForTarget(apply, documentObject, windowObject)
  }

  if (documentObject.readyState === "loading") {
    documentObject.addEventListener("DOMContentLoaded", start, { once: true })
    return
  }

  start()
}

// Turbo frames, lazy sections, and client-rendered widgets arrive after the
// first attempt, so watch the document until the element shows up or the
// budget runs out.
function watchForTarget(apply, documentObject, windowObject) {
  const root = documentObject.documentElement || documentObject.body
  if (!windowObject.MutationObserver || !root) return

  const observer = new windowObject.MutationObserver(() => {
    if (apply()) stop()
  })
  const stop = () => {
    observer.disconnect()
  }

  observer.observe(root, { childList: true, subtree: true, attributeFilter: ["class"] })
  windowObject.setTimeout(stop, MATCH_BUDGET_MS)
}

if (typeof document !== "undefined" && typeof window !== "undefined") {
  installReviewHighlight()
}
