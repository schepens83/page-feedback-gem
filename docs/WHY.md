---
last_updated: 2026-08-08
---

# Why

## Purpose

PageFeedback turns feedback on a rendered Rails page into precise, reviewable
work for a coding agent. It exists because prose bug reports lose the page,
element, browser context, and reviewer intent that make feedback actionable.
The gem preserves a feedback loop proven in Diagnostic Engine while making it
reusable by Rails applications without copying application-specific code. It is
for teams that want capture, human review, and durable export inside the host
application rather than in a separate feedback service.

## Decisions

### Package the complete feedback loop

Capture by itself only moves the ambiguity downstream. PageFeedback owns the
path from selecting an element through review and export so a reviewer can
refine raw observations before they become implementation input. The export is
vendor-neutral because the durable value is good context, not integration with
one coding agent.

### Run inside the host Rails application

The host already has the page, session, users, middleware, database, and deploy
boundary needed to understand feedback. A mountable engine can reuse those
facilities while keeping feature code namespaced and independently maintained.
A hosted service or separate frontend would add an integration boundary without
improving the core loop.

### Keep authentication optional and host-controlled

Some useful installations are personal or anonymous; others must enforce host
roles. The engine therefore has open defaults and explicit callbacks for actor
resolution and authorization. It does not guess that a `User` model exists or
let request parameters choose an identity.

### Separate review decisions from export history

Approval answers whether feedback is currently accepted. Export history answers
whether a particular revision was handed off. Combining those ideas in one
status loses information and cannot represent an approved comment that changed
after export, so exports are immutable batches and freshness is derived from
meaningful content fingerprints.

### Preserve rich capture context within strict boundaries

The selected element, nearby markup, browser errors, navigation history, and
viewport often explain a report better than its text. That context stays in the
product, but is size-limited, escaped, and restricted to local replay paths so
useful diagnostics do not become an unbounded or unsafe capture system.

### Optimize the first release for the proven Rails stack

Version 1 targets Rails 8 with Turbo, Stimulus, Importmap, and Propshaft because
that is the environment the source workflow already serves. Rails 7 adapters,
JavaScript bundlers, multi-tenancy, notifications, screenshots, and external
integrations are deferred until real usage demonstrates that their complexity
belongs in the gem.

## Constraints

- The host application remains in control of identity, authorization, layout,
  data, and deployment.
- Diagnostic Engine at commit
  `058e92c75b79d4592b622f6a16ca1f62d9b9c493` is the fidelity baseline for the
  original browser and review behavior.
- Licensing and publication terms are intentionally undecided during the
  initial scaffold; release metadata must not imply a license that has not been
  chosen.

## Future intent

The first release should be proven by replacing Diagnostic Engine's local page
feedback implementation with the packaged engine. Broader integrations belong
after that adoption demonstrates parity and exposes concrete needs.
