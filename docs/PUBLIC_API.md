# Public API

This document is the compatibility contract for host applications. APIs are
planned until their implementation phase is complete.

## Configuration

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(_controller) { nil }
  config.capture_authorizer = ->(_controller) { true }
  config.review_authorizer = ->(_controller) { true }
  config.actor_label = ->(actor) { actor.respond_to?(:email) ? actor.email : actor.to_s }
  config.categories = {
    "bug" => "Bug", "idea" => "Idea",
    "question" => "Question", "compliment" => "Compliment"
  }
  config.default_category = "idea"
  config.activation_shortcut = { alt: true, key: "f" }
  config.ignored_css_classes = []
  config.source_locator = ->(_comment) { nil }
  config.export_formatter = PageFeedback::Exporters::Markdown
end
```

Callbacks receive the current engine controller, except `actor_label`, which
receives the resolved actor, and `source_locator`, which receives a comment.
The formatter responds to `.call(comments:, generated_at:)` and returns a UTF-8
String without persisting or mutating comments. `PageFeedback.reset_configuration!`
is public for test isolation.

## Helpers

```erb
<head><%= page_feedback_head %></head>
<body><%= page_feedback_widget %><%= yield %></body>
```

The head helper emits namespaced CSS and the replay module once. The widget
helper returns an empty safe string when capture is denied and suppresses capture
chrome in replay mode. Server authorization remains authoritative.

## Domain methods

`PageFeedback::Comment` exposes status predicates, `effective_text`,
`approve!(reviewer:)`, `reject!(reviewer:)`, `return_to_pending!(reviewer:)`,
`export_fingerprint`, `export_state`, and `ready_for_export?`, plus status,
category, page, recency, and export-readiness scopes.

`PageFeedback::Export.create_from!(comments:, actor:, formatter:)` creates one
immutable export from currently ready comments and records exact ordered
membership. Models may be extended with normal Rails concerns, but documented
domain behavior must remain compatible.

## Routes and commands

The engine provides capture at `POST /comments`; review pages, comments,
approval/rejection resources, bulk resources, and immutable exports below
`/review`. The host chooses the mount prefix, `/feedback` by default.

```bash
bin/rails generate page_feedback:install --help
bin/rails page_feedback:doctor
PAGE_FEEDBACK_FORMAT=json bin/rails page_feedback:doctor
bundle exec page_feedback help
bundle exec page_feedback docs
bundle exec page_feedback version
```
