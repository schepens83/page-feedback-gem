# Public API

This document is the compatibility contract for host applications. Configuration,
authorization, helper registration, Importmap composition, the domain model,
capture, contextual review, and immutable export workflows are implemented;
installation workflows remain planned until their roadmap phase completes.

## Configuration

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(_controller) { nil }
  config.capture_authorizer = ->(_controller) { true }
  config.review_authorizer = ->(_controller) { true }
  config.actor_label = ->(actor) { actor.respond_to?(:email) ? actor.email : actor.to_s }
  config.categories = {
    "bug" => "Bug", "idea" => "Idea",
    "question" => "Question", "compliment" => "Compliment"
  }
  config.default_category = "idea"
  config.activation_shortcut = { alt: true, key: "f" }
  config.ignored_css_classes = []
  config.source_locator = ->(_comment) { nil }
  config.export_formatter = PageFeedback::Exporters::Markdown
end
```

Callbacks receive the current engine controller, except `actor_label`, which
receives the resolved actor, and `source_locator`, which receives a comment.
The formatter responds to `.call(comments:, generated_at:)` and returns a UTF-8
String without persisting or mutating comments. `PageFeedback.reset_configuration!`
is public for test isolation.

Configuration is process-global and intended to be assigned during host boot.
Each reset receives fresh mutable category, shortcut, and ignored-class values.
The default formatter produces deterministic grouped Markdown with escaped user
text, safe code fences, source locations, reviewer notes, and captured HTML.

## Helpers

```erb
<head><%= page_feedback_head %></head>
<body><%= page_feedback_widget %><%= yield %></body>
```

The head helper emits namespaced CSS and the replay module at most once per
request. The widget renders the server-owned capture form at the engine's actual
mount path. It returns an empty safe string when capture is denied and suppresses
capture chrome in replay mode. Server authorization remains authoritative.

The widget's Stimulus controller uses `activation_shortcut` (Alt+F by default),
removes every class listed in `ignored_css_classes` from generated selectors,
and populates only the documented capture fields. The picker is input-adaptive:
a mouse click picks directly, while touch and pen taps stage a candidate behind
a confirmation bar. It excludes only PageFeedback's own chrome; every host
element, including interactive controls, is selectable. Element and parent
markup, console errors, and navigation entries are capped before submission as
well as on the server. Captured context also includes `pointer_type` (`mouse`,
`touch`, or `pen`), `device_pixel_ratio`, and `orientation` (`portrait` or
`landscape`), each normalized server-side to a small whitelist or bounded
numeric.

## Floating chrome placement

The trigger, capture-mode indicator, and toasts are viewport-fixed and read two
namespaced CSS custom properties, both defaulting to `1.25rem` (`0.75rem` below
36rem) with safe-area insets added on top:

```css
:root {
  --page-feedback-offset-bottom: 5.5rem; /* clear a fixed footer or tab bar */
  --page-feedback-offset-inline: 1.25rem;
}
```

While the capture modal is open it also publishes
`--page-feedback-visual-viewport-height` and
`--page-feedback-visual-viewport-offset-bottom` on the dialog, so the small-screen
bottom sheet sits above the on-screen keyboard instead of below the layout
viewport. Both fall back to `100dvh` and `0px` without JavaScript.

PageFeedback does not detect host footers. Hosts own the collision, usually by
raising the bottom offset inside their own media query, or by setting
`config.trigger_visible = false` and activating capture from their own control
or the keyboard shortcut.

## Domain methods

`PageFeedback::Comment` exposes status predicates, `effective_text`,
`approve!(reviewer:)`, `reject!(reviewer:)`, `return_to_pending!(reviewer:)`,
`export_fingerprint`, `export_state`, and `ready_for_export?`, plus status,
category, page, recency, and export-readiness scopes.

`export_state` returns `never_exported`, `exported`, or
`changed_since_export`. `ready_for_export?` is true only for an approved revision
without a matching historical fingerprint. `source_location` delegates to the
configured host callback and contributes to `export_fingerprint`.

`PageFeedback::Export.create_from!(comments:, actor:, formatter:, label: nil)`
creates one immutable export from currently ready comments and records exact
ordered membership. The optional immutable label exposes import provenance in
history and detail views. Models may be extended with normal Rails concerns,
but documented domain behavior must remain compatible.

`create_from!` rejects empty, duplicate, unpersisted, or no-longer-ready
selections. It preserves the caller's comment order, locks and rechecks the
records, renders once, and stores the body digest plus item fingerprints in one
transaction. Persisted exports and export items are read-only.

## Routes and commands

The engine provides capture at `POST /comments`; page queues, comment edits,
approval/rejection resources, and bulk decision resources below `/review`. The
host chooses the mount prefix, `/feedback` by default. Export history, preview,
creation, HTML display, and `.md` download live under `/review/exports`. Every
review screen links back to the host application root from its header when the
host defines a root route; `page_feedback_host_root_path` returns that path, or
`nil` when it does not exist.

Export preview renders the configured formatter without persistence. Creation
accepts selected ready comment IDs in caller order, locks and rechecks them, and
stores the formatter result as an immutable snapshot. History, HTML display,
copy, and download always use that stored body. A custom formatter is any
callable accepting the documented keyword arguments and returning a string.

Capture accepts Turbo Stream, HTML, and JSON at `POST /comments`. It normalizes
legacy camelCase context, ignores submitted actor and review-state fields,
persists a pending comment, and returns validation errors in the requested
format. Review pages expose `pending`, `ready`, `exported`, `changed`, `rejected`,
and `all` filters plus category composition. Page keys are URL-safe encodings
that decode only to validated local paths. Denied access returns 403 for every
review route and format.

```bash
bin/rails generate page_feedback:install --help
bin/rails page_feedback:doctor
PAGE_FEEDBACK_FORMAT=json bin/rails page_feedback:doctor
bundle exec page_feedback help
bundle exec page_feedback docs
bundle exec page_feedback version
```

The install generator is idempotent and supports a local mount path, route,
layout, and Stimulus skip options plus explicit forced replacement with a visible
diff. Its destroy form removes only exact generated files and insertions.

The Rails doctor task and standalone `doctor` command use the same
`PageFeedback::Diagnostics` report. Human output is the default;
`PAGE_FEEDBACK_FORMAT=json` or `doctor --json` emits stable `version`, `ok`, and
`checks` keys. Required failures return a nonzero status, while warnings—most
notably the open authorization defaults—do not.
