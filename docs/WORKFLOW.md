# Workflow

## Capture

Alt+F enters element-selection mode, and picking is input-adaptive. With a mouse,
hover previews the target and a click suppresses its ordinary action and opens
the feedback modal, native `<dialog>` styled as a centered panel on wide screens
and a bottom sheet on narrow ones. With touch or pen, a tap stages a candidate
element and shows a confirmation bar (Add feedback / Choose parent / Cancel)
instead of picking immediately; "Choose parent" walks up to a wider ancestor,
one step per tap, and stops at the document body. A tap that lands on a
non-interactive descendant (an icon inside a button, say) promotes the candidate
to its nearest semantic ancestor (link, button, form control, label, summary, or
`role="button"`). Escape and Ctrl+Enter still cancel and submit. The client
captures bounded element and browser context, including pointer type, device
pixel ratio, and orientation. The server authorizes independently, strips query
strings and fragments from local paths, normalizes context keys, resolves any
actor from host code, and creates a pending comment.

The capture workflow is implemented. All host elements, including interactive
controls such as links, buttons, and form fields, are selectable; only
PageFeedback's own engine chrome is excluded. Page interaction (clicks) is
suppressed while capture mode is active, so the ordinary action of the tapped or
clicked element never fires; scrolling and pinch zoom stay native throughout.
The picker removes configured runtime classes from stable selectors and records
capped HTML, console, navigation, viewport, and scroll context. HTML submissions
redirect back to the host page, Turbo submissions replace the modal and append a
toast, and JSON submissions return either the new identifier and pending state or
a field error object. Invalid context collections normalize to empty arrays;
client actor and status fields are never permitted.

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

The implemented queue groups comments by original page and replays that local
page in a sandboxed, visually noninteractive iframe. A highlighter restores the
approximate scroll position and catches invalid or stale selectors without
breaking the host page. Reviewers can filter by physical or derived state, refine
the feedback, add notes, approve or reject, return a decision to pending, and
advance without losing the active state or category filter. Finishing the last
matching item on one page continues directly to the next matching page instead
of returning to the page overview. The overview can also approve the entire
pending queue at once; when a category filter is active, that decision applies
only to pending feedback in that category and never changes rejected feedback.

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

Phase 6 exposes the complete export workflow. Reviewers select ready comments in
their intended order, inspect a non-persistent preview, create one immutable
batch, and revisit its stored Markdown through history, copy, or download. The
default formatter groups by sorted page path and category, includes effective
feedback, notes, source locations, selectors, and captured HTML, and safely
escapes text and code fences. Formatter substitution is a configured callable,
so hosts can change representation without changing snapshot semantics.

## Queue filters

The primary filters are Pending, Ready to export, Exported, Changed, Rejected,
and All. Category filtering composes with those views. Page rows report counts
for each state so reviewers can understand the queue without opening every item.
