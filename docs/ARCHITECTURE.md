# Architecture

## Boundary

PageFeedback is one isolated, mountable Rails engine. It runs in the host Rails
process and shares the host database, session, middleware, and deployment, while
all feature code remains in the gem. Host integration is limited to an engine
mount, initializer callbacks, layout helpers, copied migrations, and Stimulus
proxy controllers.

```text
Host layout helpers
  └─ capture controller → CommentsController#create → Comment (pending)
                                                   ↓
Host page in sandboxed iframe ← review queue ← reviewer decision
                                                   ↓
                         approved current revisions
                                                   ↓
                         Export + ordered ExportItems
                                                   ↓
                           stored Markdown snapshot
```

## Components

- `PageFeedback::Configuration` stores host callbacks and presentation options.
- `PageFeedback::Engine` isolates the namespace and composes Rails integration.
- `Comment` owns review transitions and export-freshness derivation.
- `Export` atomically persists an immutable rendered body and exact membership.
- Capture controllers authorize, normalize bounded input, and resolve host actors.
- Review controllers expose REST resources for queues, edits, decisions, and
  exports.
- Browser modules select elements, record bounded context, and replay highlights.
- The installer and diagnostics object make host integration observable.

Phase 1 establishes the first integration boundaries as executable seams:
configuration is typed and documented, engine controllers inherit the host
controller, capture and review policy failures return 403, host helpers are
registered, and the engine Importmap is composed before the host map is drawn.

Phase 2 implements the persistence boundary with portable Rails migrations.
Comments own review transitions and meaningful-content fingerprints; exports own
atomic snapshot creation; export items own immutable ordered membership. A
comment's export state is derived from its current fingerprint and history, never
stored as a review status.

Phase 3 implements the capture request boundary. The host helper evaluates the
same policy contract used by the endpoint, produces mount-aware server-rendered
markup, and disappears during replay. `CommentsController#create` permits only
capture fields, resolves actor identity from the host callback, normalizes
bounded context, and negotiates Turbo Stream, HTML, or JSON responses.

Phase 4 implements the browser boundary as small Importmap modules. Pure selector,
context, shortcut, and replay functions remain independently testable; the
Stimulus controller only coordinates those modules with server-rendered targets.
The engine loads the Propshaft and Stimulus railties explicitly, pins every
module import, and ships CSS whose selectors and custom properties are scoped to
`page-feedback`.

Phase 5 implements contextual review as REST resources. A small `ReviewPage`
read model calculates page-level counts while `Comment` retains filter and state
semantics. Nested page queues decode validated local path keys, build sandboxed
replay URLs, and preserve filters through edits and decisions. Approval,
rejection, reset, and bulk operations remain separate resources under one
authorization-enforcing base controller.

Phase 6 implements immutable export snapshots. Preview calls the configured
formatter without persistence. Creation locks and rechecks the caller's ordered
selection, renders once, and atomically stores the body, membership positions,
and revision fingerprints. History, HTML display, clipboard copy, and Markdown
download all read that stored body. The default formatter groups deterministically
and escapes untrusted text while choosing safe fences for captured code.

## Dependencies

The engine depends on Rails 8, Turbo Rails, Stimulus Rails, Importmap Rails, and
Propshaft. Browser code is shipped as importmap modules; the host's existing
Stimulus application loads small generated proxies. Node is used only for the
dependency-free development test suite, never as a host runtime dependency, and
the engine does not start a second Stimulus application.

## Data flow

The browser sends a local page path, selected element context, and feedback.
The server authorizes the request, resolves the actor from trusted host code,
normalizes the context, and persists a pending comment. Review transitions set
decision timestamps and reviewer identity atomically. Export creation locks and
rechecks selected approved comments, renders once, and stores the body plus each
revision fingerprint in one transaction.

## Trust boundaries

Host configuration callbacks are trusted application code. Request parameters,
captured HTML, selectors, paths, and feedback text are untrusted. The engine
never derives actor identity from request data, never replays an external URL,
and never renders captured markup as live HTML.

## Durable decisions

- [Isolated mountable engine](decisions/0001-isolated-mountable-engine.md)
- [Host integration callbacks](decisions/0002-host-integration-callbacks.md)
- [Export batches and fingerprints](decisions/0003-export-batches-and-fingerprints.md)
- [Importmap and Stimulus integration](decisions/0004-importmap-and-stimulus-integration.md)
- [Open default authorization](decisions/0005-open-default-authorization.md)
