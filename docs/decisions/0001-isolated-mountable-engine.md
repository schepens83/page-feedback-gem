# ADR 0001: Use one isolated mountable engine

**Status:** accepted — 2026-08-08

## Decision

Package capture, review, and export as one isolated Rails mountable engine.

## Rationale

The feature needs routes, controllers, models, views, assets, migrations, and a
dummy host. Isolation prevents collisions with common host constants and routes
while sharing the host's database, session, middleware, and deployment. A plain
utility gem cannot own these boundaries; copied generators would fork the code.
