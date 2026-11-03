# Forwarding feedback between installations — plan

**Status:** proposed, not started — 2026-11-03
**Replaces:** the QR "Send to phone" handoff from 0.1.3
**Target release:** 0.2.0 (removes a public feature, adds migrations)

## Why

One host app can run as more than one installation: production, plus an
offline copy on a laptop that cannot reach the network, a staging server, or a
developer's machine. Feedback captured on a secondary installation is about the
same app, so it should be triaged in one place, the primary installation, next
to everything else.

0.1.3 moved a Markdown *export* to a phone through QR codes. In practice an
export of any size needs too many codes to scan comfortably, and a Markdown
export is the end of the pipeline: the receiving side could only read it, not
triage it. Forwarding moves the *comments themselves*, before triage, in one
step.

## How it works

The secondary installation's server usually cannot reach the primary (that is
why it is offline), but the reviewer's browser can open both. So the browser
carries the data:

```text
secondary: select comments → Forward → opens one link
  https://primary.example/feedback/review/handoff#pf2.<deflated JSON>
primary:   handoff page decodes the fragment in the browser → preview
           → Import (same-origin POST, CSRF, review authorization)
           → comments created as pending, skipping any already present
```

A URL fragment is never sent to a server and has no practical size limit in
current browsers (Chromium and Edge accept URLs of 2 MB), so one link replaces
any number of QR codes. The primary only ever receives the data through the
normal authenticated import form, after a person has seen the preview.

Neither installation needs a token, a shared secret or a server-to-server
connection.

## Decisions (agreed 2026-11-03)

1. **Forward untriaged comments.** The secondary only collects; all judging
   happens on the primary. Forwarding is offered for pending comments.
2. **Send all context**, including `element_html` and the captured `context`,
   so the comment is as useful on the primary as it was on the secondary. The
   preview on the primary shows what arrived. (A host worried about content
   leaving an installation can simply not configure forwarding.)
3. **Forwarded comments are hidden on the secondary**, not deleted, so a failed
   import can be sent again.
4. **The QR handoff is removed**, together with the `rqrcode` dependency.

### "Forwarded" is not a review status

Review status answers *what did a reviewer decide* (pending, approved,
rejected). Forwarding answers *where did this go*, the same kind of fact as
"exported". The engine already keeps those apart: export state is derived from
immutable export batches, never stored on the comment (ADR 0003). Forwarding
follows the same pattern (ADR 0006):

- A `Forward` batch records which comments were sent, when, by whom and to
  which URL. It is immutable.
- A comment is *forwarded* when it belongs to any forward batch. The review
  queues leave forwarded comments out by default and a **Forwarded** filter
  shows them.
- The status column keeps its three values. Approval, rejection and export
  logic do not change.

Like a postmark on a letter: it tells you where the letter went, not what
anyone thought of it.

## Data model

New migrations, database-neutral (they must run on SQLite and PostgreSQL):

**`page_feedback_comments`** gains:

| Column | Type | Purpose |
|---|---|---|
| `uuid` | string, not null, unique index | Stable identity across installations. Generated on create; existing rows backfilled. Import skips a uuid that already exists, so importing twice is harmless. |
| `origin` | string, null | Name of the installation the comment came from (`nil` = captured here). Shown as "via …" in review. |
| `submitter_label` | string, null | The submitter's display label at the source. Actors are host records and cannot cross installations, so an imported comment has no `submitter`, only this label. |

**`page_feedback_forwards`**: `destination_url`, `created_by` (polymorphic,
optional), timestamps.

**`page_feedback_forward_items`**: `forward_id`, `comment_id`, unique on the
pair.

## Payload (`pf2`)

The fragment is `pf2.` followed by base64url of raw-deflated UTF-8 JSON:

```json
{
  "format": "page_feedback.forward",
  "version": 1,
  "source": "Work laptop",
  "comments": [
    {
      "uuid": "…", "category": "idea", "comment_text": "…", "refined_text": null,
      "page_path": "/kompas", "page_title": "…", "controller_action": "…",
      "css_selector": "…", "element_html": "…", "context": {},
      "created_at": "2026-11-03T09:12:00Z", "submitter_label": "Sander"
    }
  ]
}
```

On import every comment goes through the same validations and length limits as
a captured one: the page path must be a local path, an unknown category falls
back to `default_category`, and HTML is stored and shown as text. `created_at`
is kept, so the queue shows when the thought was captured. At most 200
comments per forward; the forward screen splits larger selections.

## Configuration

```ruby
PageFeedback.configure do |config|
  # Where forwarded comments go: the primary installation's handoff page.
  # nil (the default) hides the Forward action.
  config.handoff_url = "https://primary.example/feedback/review/handoff"

  # How this installation names itself at the destination ("via …").
  config.instance_name = "Work laptop"
end
```

`handoff_url` keeps its name and meaning from 0.1.3. Its default changes from
"this host" to `nil`, because forwarding to yourself makes no sense. The
primary needs no configuration to *receive*; its handoff page always accepts
an import from a signed-in reviewer.

## Security

- Import is an ordinary state-changing request on the primary: review
  authorization, CSRF and a visible preview first. Opening a forward link
  alone changes nothing.
- The payload is untrusted input, held to capture's validations. It cannot set
  status, reviewer or submitter; every imported comment arrives pending and
  unreviewed.
- `origin` and `submitter_label` are labels a reviewer supplies, not proof of
  identity. That is acceptable because only reviewers can import.
- The data never reaches a server log or proxy on the way, because it travels in
  the fragment. It does sit in the secondary's browser history until the
  handoff page removes the fragment after a successful import.
- Replay on the primary loads the page path on the primary, so it shows the
  primary's data and the element may not exist there. The captured selector,
  HTML and context remain the reference.

## Phases

1. **Receive.** Migrations (uuid with backfill, origin, submitter label);
   `pf2` decoding and preview on the handoff page; `Review::ImportsController#create`
   with validation and uuid de-duplication; a "via …" label in review.
2. **Send.** Forward batches; a Forward action on the review pages for pending,
   unforwarded comments; the queues leave forwarded comments out and gain a
   Forwarded filter; a forward page that reopens the link for a retry;
   `config.instance_name`.
3. **Remove the QR handoff.** Delete `Handoff`, the export page section,
   the `pf1` decoder and `rqrcode`. CHANGELOG, PUBLIC_API, WORKFLOW,
   SECURITY, ADR 0006. Release 0.2.0.
4. **Host adoption (schepenscc).** Bump to `v0.2.0`, copy and run the
   migrations on production and on the laptop (SQLite), set `instance_name`
   per environment, and update `docs/page-feedback.md` and
   `docs/windows-local.md`.

Each phase is test-first and leaves the gate green: specs, JS tests, RuboCop,
RBS, YARD and gem build.

## Out of scope

- Server-to-server sync, tokens or webhooks.
- Forwarding back from the primary, or keeping two installations in sync.
- Forwarding approved comments or exports.
- Screenshots or attachments.
