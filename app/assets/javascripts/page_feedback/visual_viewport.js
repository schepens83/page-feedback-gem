const HEIGHT_PROPERTY = "--page-feedback-visual-viewport-height"
const OFFSET_PROPERTY = "--page-feedback-visual-viewport-offset-bottom"

// Fixed elements — including modal dialogs in the top layer — are laid out
// against the layout viewport. On-screen keyboards and pinch zoom shrink only
// the visual viewport, so a bottom-anchored sheet ends up under the keyboard.
// Publish the visible height and the hidden bottom strip so CSS can correct it.
export function trackVisualViewport(element, windowObject = window) {
  const viewport = windowObject.visualViewport
  if (!viewport) return () => {}

  const apply = () => {
    const layoutHeight = windowObject.document.documentElement.clientHeight
    const hiddenBottom = Math.max(layoutHeight - (viewport.height + viewport.offsetTop), 0)

    element.style.setProperty(HEIGHT_PROPERTY, `${viewport.height}px`)
    element.style.setProperty(OFFSET_PROPERTY, `${hiddenBottom}px`)
  }

  apply()
  viewport.addEventListener("resize", apply)
  viewport.addEventListener("scroll", apply)

  return () => {
    viewport.removeEventListener("resize", apply)
    viewport.removeEventListener("scroll", apply)
    element.style.removeProperty(HEIGHT_PROPERTY)
    element.style.removeProperty(OFFSET_PROPERTY)
  }
}
