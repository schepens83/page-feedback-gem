# ADR 0002: Integrate hosts through callbacks

**Status:** accepted — 2026-08-08

## Decision

Resolve the current actor, capture authorization, review authorization, actor
labels, and source locations through initializer callbacks.

## Rationale

Host applications already have different user and authorization systems. Small
callbacks keep that policy with the host and avoid a mandatory User model or
authentication dependency. Request data is never an identity source.
