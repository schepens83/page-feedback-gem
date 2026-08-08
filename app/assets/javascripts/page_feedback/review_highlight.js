const DEFAULT_IGNORED_CLASSES = [
  "revealed",
  "scene-visible",
  "cf-metric-fill--animate",
  "cf-copilot-mock--slide-in"
]

export function sanitizeReplaySelector(selector, ignoredClasses = DEFAULT_IGNORED_CLASSES) {
  return ignoredClasses.reduce((value, className) => {
    const escaped = className.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    return value.replace(new RegExp(`\\.${escaped}\\b`, "g"), "")
  }, selector)
}

export function applyReviewHighlight({
  selector,
  scrollY = 0,
  ignoredClasses,
  documentObject = document,
  windowObject = window
}) {
  try {
    const target = documentObject.querySelector(sanitizeReplaySelector(selector, ignoredClasses))
    if (!target) return false

    target.classList.add("page-feedback-review-highlight")
    if (scrollY > 0 && windowObject.scrollTo) {
      windowObject.scrollTo({ top: Math.max(0, scrollY - 80), behavior: "instant" })
    } else {
      target.scrollIntoView({ block: "center", behavior: "instant" })
    }
    return true
  } catch (_error) {
    return false
  }
}

export function installReviewHighlight({
  documentObject = document,
  windowObject = window,
  locationObject = location
} = {}) {
  const parameters = new URLSearchParams(locationObject.search)
  const selector = parameters.get("page_feedback_selector")
  if (!selector) return

  const apply = () => applyReviewHighlight({
    selector,
    scrollY: Number.parseInt(parameters.get("page_feedback_scroll") || "0", 10),
    documentObject,
    windowObject
  })

  if (documentObject.readyState === "loading") {
    documentObject.addEventListener("DOMContentLoaded", apply, { once: true })
  } else {
    apply()
  }
}

if (typeof document !== "undefined" && typeof window !== "undefined") {
  installReviewHighlight()
}
