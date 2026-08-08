# ADR 0004: Compose Importmap and reuse host Stimulus

**Status:** accepted — 2026-08-08

## Decision

Ship browser modules through an engine importmap and generate small proxy
controllers for the host's existing Stimulus application.

## Rationale

This matches the Rails 8 source stack, avoids an npm package and build step, and
prevents competing Stimulus applications. Hosts without the standard loader get
explicit manual registration instructions instead of guessed integration.
