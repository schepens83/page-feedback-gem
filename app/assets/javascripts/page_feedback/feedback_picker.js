export function startFeedbackPicker({ documentObject = document, shouldSkip, onPick }) {
  let highlightedElement
  const indicator = documentObject.createElement("div")
  const root = documentObject

  documentObject.body.classList.add("page-feedback-capture-mode")
  indicator.className = "page-feedback-mode-indicator"
  indicator.textContent = "Feedback mode — click an element · Alt+F or Escape to exit"
  documentObject.body.appendChild(indicator)

  const clearHighlight = () => {
    if (!highlightedElement) return
    highlightedElement.classList.remove("page-feedback-capture-highlight")
    highlightedElement = undefined
  }
  const hover = (event) => {
    clearHighlight()
    if (shouldSkip(event.target)) return
    event.target.classList.add("page-feedback-capture-highlight")
    highlightedElement = event.target
  }
  const pick = (event) => {
    if (shouldSkip(event.target)) return
    event.preventDefault()
    event.stopPropagation()
    const target = event.target
    stop()
    onPick(target)
  }
  const stop = () => {
    documentObject.body.classList.remove("page-feedback-capture-mode")
    clearHighlight()
    indicator.remove()
    root.removeEventListener("mouseover", hover)
    root.removeEventListener("mouseout", clearHighlight)
    root.removeEventListener("click", pick, true)
  }

  root.addEventListener("mouseover", hover)
  root.addEventListener("mouseout", clearHighlight)
  root.addEventListener("click", pick, true)
  return stop
}
