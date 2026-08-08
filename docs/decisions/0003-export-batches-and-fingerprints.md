# ADR 0003: Store export batches and content fingerprints

**Status:** accepted — 2026-08-08

## Decision

Persist each export body and its ordered comment membership immutably. Store a
fingerprint of every exported comment revision.

## Rationale

Review approval and handoff history answer different questions. Immutable
snapshots make copy/download reproducible, while meaningful fingerprints detect
reviewer edits without treating unrelated timestamp touches as new work.
