const SKIP_TAGS = new Set(["NAV", "FORM", "INPUT", "TEXTAREA", "SELECT", "BUTTON"])
const MAX_ELEMENT_HTML = 2000
const MAX_PARENT_HTML = 1000

function classNames(element) {
  return Array.from(element.classList || [])
}

function escapeIdentifier(value) {
  if (globalThis.CSS?.escape) return globalThis.CSS.escape(value)

  return String(value).replace(/[^a-zA-Z0-9_-]/g, (character) => {
    return `\\${character.codePointAt(0).toString(16)} `
  })
}

export function shouldSkipElement(element, { root = document.body } = {}) {
  let node = element

  while (node && node !== root) {
    if (SKIP_TAGS.has(node.tagName)) return true
    if (classNames(node).some((name) => name.startsWith("page-feedback-"))) return true
    node = node.parentElement
  }

  return false
}

export function buildSelector(element, { root = document.body, ignoredClasses = [] } = {}) {
  const ignored = new Set(ignoredClasses)
  const parts = []
  let node = element

  while (node && node !== root) {
    if (node.id) {
      parts.unshift(`#${escapeIdentifier(node.id)}`)
      break
    }

    let part = node.tagName.toLowerCase()
    const stableClasses = classNames(node).filter((name) => !ignored.has(name))
    part += stableClasses.map((name) => `.${escapeIdentifier(name)}`).join("")

    const siblings = Array.from(node.parentElement?.children || [])
      .filter((child) => child.tagName === node.tagName)
    if (siblings.length > 1) {
      const position = Array.from(node.parentElement.children).indexOf(node) + 1
      part += `:nth-child(${position})`
    }

    parts.unshift(part)
    node = node.parentElement
  }

  return parts.join(" > ")
}

export function captureElement(element, options = {}) {
  return {
    selector: buildSelector(element, options),
    elementHtml: element.outerHTML.slice(0, MAX_ELEMENT_HTML),
    parentHtml: element.parentElement?.outerHTML.slice(0, MAX_PARENT_HTML) || "",
    tagName: element.tagName.toLowerCase()
  }
}
