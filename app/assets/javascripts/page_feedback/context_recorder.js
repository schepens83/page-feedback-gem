function pushBounded(collection, value, limit) {
  collection.push(value)
  if (collection.length > limit) collection.splice(0, collection.length - limit)
}

export function createContextRecorder({
  consoleObject,
  historyObject,
  windowObject,
  now = Date.now
}) {
  const consoleErrors = []
  const navigationHistory = []
  const originalConsoleError = consoleObject.error
  const originalPushState = historyObject.pushState
  const originalReplaceState = historyObject.replaceState

  const trackNavigation = (url) => {
    pushBounded(navigationHistory, { url: String(url), timestamp_ms: now() }, 5)
  }
  const trackPopstate = () => trackNavigation(windowObject.location.href)

  consoleObject.error = function pageFeedbackConsoleError(...argumentsList) {
    pushBounded(
      consoleErrors,
      { message: argumentsList.map(String).join(" "), timestamp_ms: now() },
      10
    )
    return originalConsoleError.apply(this, argumentsList)
  }
  historyObject.pushState = function pageFeedbackPushState(state, title, url) {
    if (url) trackNavigation(url)
    return originalPushState.call(this, state, title, url)
  }
  historyObject.replaceState = function pageFeedbackReplaceState(state, title, url) {
    if (url) trackNavigation(url)
    return originalReplaceState.call(this, state, title, url)
  }
  windowObject.addEventListener("popstate", trackPopstate)

  return {
    capturePageContext(parentHtml) {
      return {
        parentHtml,
        viewport: `${windowObject.innerWidth}x${windowObject.innerHeight}`,
        scrollY: Math.round(windowObject.scrollY),
        consoleErrors: JSON.stringify(consoleErrors),
        navigationHistory: JSON.stringify(navigationHistory)
      }
    },
    disconnect() {
      consoleObject.error = originalConsoleError
      historyObject.pushState = originalPushState
      historyObject.replaceState = originalReplaceState
      windowObject.removeEventListener("popstate", trackPopstate)
    }
  }
}

let browserRecorder

export function installContextRecorder() {
  if (!browserRecorder) {
    browserRecorder = createContextRecorder({
      consoleObject: console,
      historyObject: history,
      windowObject: window
    })
  }
  return browserRecorder
}

export function capturePageContext(parentHtml) {
  return installContextRecorder().capturePageContext(parentHtml)
}
