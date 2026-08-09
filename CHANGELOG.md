# Changelog

All notable changes will be recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project intends
to use semantic versioning after its first release.

## [Unreleased]

### Added

- Initial architecture and implementation plan.
- Documentation spine for consumers, maintainers, and coding agents.
- Bootable isolated Rails engine scaffold and dummy host application.
- RSpec, RuboCop, gem packaging, and compatibility-matrix CI foundations.
- Self-contained HTML implementation report for repository review.
- Typed configuration defaults and host callback contracts.
- Server-side capture/review authorization with preserved host CSRF behavior.
- Host helper registration and composed engine Importmap module pins.
- Portable comment, export, and export-item migrations with dummy-host schema.
- Review transitions, polymorphic actors, and page/category/state scopes.
- Canonical export fingerprints and never-exported/current/changed derivation.
- Atomic immutable export snapshots with exact ordered membership.
- Authorized Turbo, HTML, and JSON feedback capture with trusted actor
  attribution, normalized bounded context, and server-side validation.
- Mount-aware host helpers with idempotent asset tags, replay suppression, and
  policy-aware server-rendered modal and toast fragments.
- Namespaced element picker, bounded browser context recorder, configurable
  capture shortcuts, Stimulus adapter, and resilient replay highlighter.
- Propshaft and Importmap asset-resolution checks plus a dependency-free Node
  test suite wired into CI.
- Page-grouped review overview with physical and derived-state filters, category
  composition, complete counts, and safe encoded page routes.
- Sandboxed in-context queues with navigation, reviewer edits, RESTful approval,
  rejection and reset resources, bulk decisions, and full escaped detail.
- Dummy-host Capybara coverage from anonymous widget capture through approval.
- Deterministic, safely escaped Markdown formatting with page and category
  grouping, source context, reviewer notes, and collision-safe code fences.
- RESTful export preview, creation, history, copy, and exact stored-body download
  with ordered membership, freshness rechecks, and formatter substitution.
- Idempotent install generator with mount, layout, and Stimulus options, safe
  reversal, mount validation, and visible forced-overwrite differences.
- Shared installation diagnostics with complete human output, stable JSON,
  warning-aware status, Rails tasks, and a standalone executable.
- Optional immutable export labels for visible legacy-import provenance in
  export history and detail views.
- Export detail metadata for the stored format and host-resolved creator label.
- Rails 8.1-compatible authorization callbacks across every review controller.
- Packaged-install diagnostics recognize Rails' timestamped engine migration filenames.
- Explicit Markdown MIME registration for Rails 8.0 export downloads.
- Reproducible Ruby 3.2/3.4 and Rails 8.0/8.1 appraisal matrix, including a
  clean dummy-host Active Storage fixture and cross-version schema loading.
- MIT licensing for the initial public release.
- Captured context now also records `pointer_type`, `device_pixel_ratio`, and
  `orientation`, each normalized server-side to a small whitelist or bounded
  numeric.
- Review screens link back to the host application root from the header when the
  host defines a root route, via the new `page_feedback_host_root_path` helper.
- Host-overridable `--page-feedback-offset-bottom` and
  `--page-feedback-offset-inline` custom properties position the floating
  trigger, capture-mode indicator, and toasts, so hosts with a fixed footer or
  mobile tab bar can lift them clear of it.

### Changed

- Restyled capture and review interfaces with a neutral grayscale palette,
  flatter controls, high-contrast focus states, light/dark-safe element
  highlights, and reduced-motion support.
- Made the capture picker input-adaptive: mouse hover and click still pick
  directly, while touch and pen taps stage a candidate behind a confirmation
  bar (Add feedback / Choose parent / Cancel) with semantic-ancestor promotion,
  so scrolling and pinch zoom stay native. Every host element, including
  interactive controls, is now selectable; only PageFeedback's own chrome is
  excluded, and page clicks are suppressed for the duration of capture mode.
- Converted the capture modal to a native `<dialog>` that renders as a bottom
  sheet on small screens, with a sticky submit row and safe-area-aware
  padding.
- Turned the floating trigger into the capture-mode banner. Arming feedback
  mode now relabels the button, marks it `aria-pressed`, and stretches it into a
  bar across small screens instead of adding a second floating indicator beside
  it; pressing it again returns it to "Give page feedback". Installations that
  hide the trigger keep the standalone indicator.
- Improved the mobile review layout: the queue stacks with the feedback card
  first and a shorter preview pane, review actions stay pinned to the bottom
  of the viewport, and touch targets across the widget meet a 44px minimum
  under `(pointer: coarse)`.

### Fixed

- Feedback capture selects the clicked element again. The picker marks the
  hovered element with `page-feedback-capture-highlight`, and the skip
  predicate treated every `page-feedback-` class as engine chrome, so the
  element under the cursor was always rejected and no click ever opened the
  modal. Transient picker state classes are now excluded from that check.
- The capture modal stays visible on phones. As a bottom sheet it was anchored
  to the layout viewport, which the on-screen keyboard opened by the autofocused
  comment field does not shrink, so the sheet sat entirely below the visible
  area. It now follows the visual viewport through
  `--page-feedback-visual-viewport-height` and
  `--page-feedback-visual-viewport-offset-bottom`.
- Alt+F re-arms feedback mode on the press after a capture. The picker stops
  itself before invoking `onPick`, so the Stimulus adapter now clears its own
  handle and no longer spends the next shortcut discarding stale state.

### Security

- Documented host-controlled authorization, CSRF, local replay, escaping, and
  request-boundary requirements.
