# ADR 0005: Permit access by default

**Status:** accepted — 2026-08-08

## Decision

Default capture and review authorization callbacks return true; the default
actor is nil. Generated configuration and diagnostics explicitly warn that
review is open.

## Rationale

The engine must work in applications without users or authentication. A hidden
deny-by-default setup would make first success fail, while an undocumented open
default would be unsafe. Visible callbacks and server enforcement make the host's
choice inspectable.
