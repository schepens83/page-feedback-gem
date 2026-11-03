# ADR 0006: Forwarding is derived from batches, not a review status

**Status:** proposed — 2026-11-03

## Decision

Record forwarding to another installation as immutable `Forward` batches with
item membership, as exports are recorded (ADR 0003). A comment is forwarded
when it belongs to a forward batch. The comment `status` column keeps exactly
pending, approved and rejected.

## Rationale

Review status records a reviewer's judgement; forwarding records where a
comment was sent. Mixing the two would make every status-driven rule
(approval, rejection, export readiness, queue filters) handle a value that is
not a judgement. A derived state also keeps the history (when, by whom, to
where), which a status value would lose, and lets a failed import be retried
by reopening the same batch.

## Consequences

Review queues filter forwarded comments out by default and offer a Forwarded
filter. A comment needs a stable `uuid` so the receiving installation can skip
one it already has.
