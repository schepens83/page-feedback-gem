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

## Dependencies

The engine depends on Rails 8, Turbo Rails, Stimulus Rails, Importmap Rails, and
Propshaft. Browser code is shipped as importmap modules; the host's existing
Stimulus application loads small generated proxies. No Node package or second
Stimulus application is introduced.

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
