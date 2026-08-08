# Security

## Host trust and authorization

Host configuration callbacks are trusted code. Capture and every review route
must enforce their respective callback on the server for HTML, Turbo, and JSON.
A denied request returns 403. Open defaults are supported but must remain obvious
in generated configuration and diagnostics.

The Phase 1 request contract verifies that denied capture and review callbacks
return 403 and receive the active engine controller. Capture requests without a
valid authenticity token are rejected before policy or endpoint behavior runs.

Actor identity always comes from `current_actor`; submitter, reviewer, and export
creator IDs in request parameters are ignored. The engine keeps Rails CSRF
protection enabled, including browser-originated JSON requests.

## Untrusted capture data

Feedback, notes, paths, selectors, context, and captured HTML are untrusted.
Views escape them, captured markup is displayed as text, and formatters fence or
escape content so it cannot accidentally restructure an export. Client limits
are backed by server-side limits.

The capture endpoint currently caps feedback at 10,000 characters, local paths
at 2,000, page titles at 500, controller/action labels at 255, selectors at
2,000, selected-element HTML at 2,500, and parent HTML at 1,250. It retains at
most 10 console summaries and 5 navigation entries, each reduced to its approved
content and timestamp keys.

## Replay

Only paths beginning with exactly one `/` are replayable. Protocol-relative,
absolute, and malformed external URLs are rejected. Query strings and fragments
are not stored. The iframe is sandboxed and visually noninteractive, and stale or
invalid selectors must fail closed without breaking the page.

## Data and exports

Rich browser context can contain sensitive application information; hosts should
apply their normal database access, retention, and backup controls. Exports are
immutable snapshots and can repeat sensitive content, so their copy/download
routes require the same review authorization as their HTML views.

## Reporting

This project is not yet released. Until a public security channel exists, report
issues privately to the repository owner and avoid including captured production
data in an issue.
