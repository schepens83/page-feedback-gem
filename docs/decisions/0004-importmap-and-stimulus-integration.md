# ADR 0004: Compose Importmap and reuse host Stimulus

**Status:** accepted — 2026-08-08
**Amended:** 2026-08-23 — review layout starts its own Stimulus application

## Decision

Ship browser modules through an engine importmap and generate small proxy
controllers for the host's existing Stimulus application.

Pages the engine renders in its own layout are the exception: that layout emits
`javascript_importmap_tags "page_feedback/review"`, and
`page_feedback/review.js` starts a Stimulus application and registers the
controllers the review UI needs.

## Rationale

This matches the Rails 8 source stack, avoids an npm package and build step, and
prevents competing Stimulus applications. Hosts without the standard loader get
explicit manual registration instructions instead of guessed integration.

Reusing the host application only reaches markup the host renders — the capture
widget and replay helpers injected through `page_feedback_head` and
`page_feedback_widget`. The review UI renders inside
`layouts/page_feedback/application`, where no host JavaScript is on the page at
all, so its `data-controller` attributes never connected and Copy Markdown was
inert. Starting an application there competes with nothing, because the host's
never loads on those pages.

## Consequences

Every controller used only on review pages must be registered in
`page_feedback/review.js`; host proxies do not cover them. The installer
therefore generates one proxy, for the capture controller, and no longer
generates a copy-controller proxy that nothing on a host page could reach. A
request spec asserts the export page loads that entrypoint so a layout change
cannot silently strip the review UI's JavaScript again.
