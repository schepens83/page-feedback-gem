# Workflow

## Capture

Alt+F enters element-selection mode. Hover previews the target, click suppresses
its ordinary action and opens the feedback modal, Escape cancels, and Ctrl+Enter
submits. The client captures bounded element and browser context. The server
authorizes independently, strips query strings and fragments from local paths,
normalizes context keys, resolves any actor from host code, and creates a pending
comment.

The server half of this workflow is implemented. HTML submissions redirect back
to the host page, Turbo submissions replace the modal and append a toast, and
JSON submissions return either the new identifier and pending state or a field
error object. Invalid context collections normalize to empty arrays; client actor
and status fields are never permitted.

## Review state

```text
pending  ──approve──▶ approved
pending  ──reject───▶ rejected
approved ──reject───▶ rejected
rejected ──approve──▶ approved
approved or rejected ──clear decision──▶ pending
```

Approval sets `approved_at`, clears `rejected_at`, and records the supplied
reviewer. Rejection does the inverse. Returning to pending clears both decision
timestamps. Reviewer refinement and notes are saved before a decision.

These transitions are implemented as atomic model updates. Anonymous reviewers
remain valid, and host actors are stored through optional polymorphic
associations.

The queue groups comments by original page and replays that local page in a
sandboxed, visually noninteractive iframe. A highlighter restores the approximate
scroll position and catches invalid or stale selectors without breaking the host
page.

## Export state

Review state and export state are independent:

| Condition | Export state | Ready? |
|---|---|---|
| Approved, no export item | Never exported | Yes |
| Approved, matching fingerprint exists | Exported | No |
| Approved, only stale fingerprints exist | Changed since export | Yes |
| Pending or rejected | Not exportable | No |

An export stores one formatter result and ordered membership records. Copy and
download always use the stored body. Editing meaningful approved content changes
its fingerprint and makes it ready again without altering earlier exports.

Phase 2 implements this derivation and atomic snapshot creation. Fingerprints
cover category, effective text, reviewer notes, page identity, selector, captured
HTML, and resolved source location; timestamps and actor labels are excluded.

## Queue filters

The primary filters are Pending, Ready to export, Exported, Changed, Rejected,
and All. Category filtering composes with those views. Page rows report counts
for each state so reviewers can understand the queue without opening every item.
