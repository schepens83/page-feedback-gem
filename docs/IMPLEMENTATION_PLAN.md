# PageFeedback Rails Engine Gem — Architecture and Implementation Blueprint

**Status:** Phase 7 implementation and automated verification complete; Phase 8 next
**Date:** 2026-08-08  
**Working gem name:** `page_feedback`  
**Ruby namespace:** `PageFeedback`  
**Source application:** `/home/sander/Projects/diagnostic-engine`  
**Source baseline:** `058e92c75b79d4592b622f6a16ca1f62d9b9c493`

This document is a self-contained handoff for creating a new repository and
giving an implementation LLM enough product, architectural, API, workflow, and
validation context to build the gem without rediscovering the original system.

The working name is intentionally concrete so code, routes, tables, and examples
are unambiguous. If the gem is renamed, do it mechanically before the first
published version or host migration.

## Instructions for the Implementation LLM

When this document is copied into the new gem repository:

1. Read this document completely before creating files.
2. Scaffold an isolated Rails mountable engine named `page_feedback`.
3. Create the documentation skeleton in Phase 0 before feature code.
4. Work through the implementation phases in order.
5. Use red-green TDD for model transitions, authorization contracts, exports,
   controller behavior, and installation diagnostics.
6. Keep commits small and scoped; push after each commit when a remote exists.
7. Do not collapse the engine into host-application code.
8. Do not add Rails 7, non-Importmap JavaScript, multi-tenancy, notifications,
   webhooks, or an external service unless the requirements are explicitly
   changed.
9. Treat the public API, state machines, route structure, and invariants in this
   document as the implementation contract.
10. If implementation reveals a genuine contradiction, document the evidence
    and ask before changing the contract.

## Executive Summary

Build `page_feedback` as an isolated, mountable Rails engine that provides a
complete in-application feedback loop:

1. A user presses Alt+F and selects an element on any host-application page.
2. A modal captures feedback plus DOM and browser context.
3. The engine persists the comment, optionally attributed to a host user.
4. A reviewer works through feedback grouped by original page, with the page
   replayed in an iframe and the selected element highlighted.
5. The reviewer refines, approves, or rejects each comment.
6. Approved current revisions are collected into immutable export batches.
7. A generic Markdown formatter produces coding-agent-friendly output.
8. The review UI clearly distinguishes never-exported, exported, and changed-
   since-export feedback.

The engine runs inside the host Rails process and uses the host database,
session, middleware, and deployment. The feature code remains in the gem. The
host receives only installation seams: an initializer, copied migrations, a
route mount, layout helper calls, and small Stimulus proxy controllers.

## Decisions Already Made

- Package the whole capture → review → export workflow, not capture alone.
- Use one isolated mountable Rails engine.
- Target Rails 8.x, Turbo, Stimulus, Importmap, and Propshaft.
- Keep rich capture enabled: selected HTML, parent HTML, console errors,
  navigation history, viewport, scroll position, selector, path, title, and
  controller/action.
- Preserve CSRF protection.
- Store the submitting user when a host user is available.
- Work without any authentication or user model; anonymous capture and open
  review are valid default behavior.
- Let authenticated host applications provide actor and authorization behavior
  through initializer callbacks.
- Produce generic Markdown through a formatter contract; do not embed Claude,
  Codex, or another vendor in the domain model.
- Record immutable exports and their exact comment membership.
- Do not implement multi-tenancy in v1.
- Do not add email, jobs, webhooks, or external notifications in v1.

## Why a Mountable Engine

Rails defines an engine as a plugin that behaves like a small Rails application
and can own routes, controllers, models, views, and assets. A mountable engine
adds namespace isolation and a dummy application for integration testing. This
feature needs every one of those boundaries, so a plain utility gem or source
generator would be the wrong abstraction.

Isolation prevents collisions with common host names such as `Comment`,
`CommentsController`, `Export`, and `ApplicationHelper`. The host application
retains final control over mounting, authentication, layout integration, and
configuration.

References:

- [Rails plugin guide](https://guides.rubyonrails.org/plugins.html)
- [Rails engine guide](https://guides.rubyonrails.org/engines.html)
- [Importmap composition for engines](https://github.com/rails/importmap-rails#composing-import-maps)

## Current Source Feature

The current implementation is an explicit human → coding-agent UI feedback
loop. Its durable purpose is recorded in:

- `docs/WHY.md:146` — page comments as a Claude-Code feedback loop.
- `README.md:77` and `README.md:118` — model and workflow summary.

The source implementation is distributed across:

- `app/models/page_comment.rb`
- `app/controllers/page_comments_controller.rb`
- `app/controllers/admin/comments_controller.rb`
- `app/controllers/admin/comment_pages/comments_controller.rb`
- `app/views/page_comments/`
- `app/views/admin/comments/`
- `app/views/admin/comment_pages/comments/`
- `app/javascript/controllers/comment_capture_controller.js`
- `app/javascript/controllers/copy_markdown_controller.js`
- `app/javascript/page_comments/`
- `app/assets/stylesheets/application.css:1300-2055`
- `config/routes.rb:30-50`
- `config/importmap.rb:9`
- `db/migrate/20260309113208_create_page_comments.rb`
- `db/migrate/20260505000001_add_category_to_page_comments.rb`
- `db/migrate/20260524120000_add_reviewer_notes_to_page_comments.rb`
- `spec/models/page_comment_spec.rb`
- `spec/requests/page_comments_spec.rb`
- `spec/requests/admin_comments_spec.rb`

Preserve the behavior, not the current class names or controller structure.

## Desired End State

A new Rails 8 application can install the gem with a short, observable flow:

```ruby
# Gemfile
gem "page_feedback", path: "../page_feedback"
```

```bash
bundle install
bin/rails generate page_feedback:install
bin/rails page_feedback:install:migrations
bin/rails db:migrate
bin/rails page_feedback:doctor
```

The generator installs:

- `config/initializers/page_feedback.rb`
- `mount PageFeedback::Engine => "/feedback"` in `config/routes.rb`
- `<%= page_feedback_head %>` in the host `<head>`
- `<%= page_feedback_widget %>` in the host `<body>`
- small host Stimulus proxy controllers that re-export gem controllers

After installation:

- Alt+F capture works on ordinary host pages.
- `/feedback/review/pages` opens the review queue.
- The default no-auth configuration permits capture and review.
- Configured host authorization is enforced server-side, not only in the UI.
- Anonymous submissions have a null submitter.
- Authenticated submissions retain a polymorphic submitter reference.
- Review decisions are independent from export history.
- Export creation stores exact Markdown and exact comment revisions.
- `page_feedback:doctor` explains any incomplete integration.

## Scope Boundaries

### In scope

- Rails mountable engine and gem packaging
- Namespaced models, controllers, helpers, views, assets, routes, migrations
- Host initializer and install generator
- Optional host actor resolution
- Capture/review authorization callbacks
- Alt+F element picker and capture modal
- Rich technical context
- Page-grouped in-context review
- Approve, reject, return to pending
- Reviewer refinement and notes
- Export preview, creation, history, copy, and Markdown download
- Export freshness detection
- Human and machine-readable installation diagnostics
- LLM-oriented repository documentation
- Migration path for the source Diagnostic Engine application

### Explicitly out of scope

- Rails 7 support
- jsbundling, Vite, Webpacker, or npm packaging
- Multi-tenancy or account scoping
- Email notifications
- Background processing
- Webhooks or issue-tracker integrations
- Screenshot capture or binary attachments
- Comment threads or replies
- Public JSON API authentication
- Localization beyond making strings structurally extractable
- A separate npm package
- A hosted SaaS service
- Automatic AI rewriting or summarization
- Automatic detection of a host `User` model
- A documentation website in v1

## Repository Documentation Architecture

No single file should try to serve users, maintainers, coding agents, generated
API references, and command discovery simultaneously. Use layered documentation
with one source of truth for each concern.

### 1. `AGENTS.md`: coding-agent entry point

Use a root `AGENTS.md` as the predictable operating manual for repository-aware
coding agents. The open AGENTS.md format recommends project overview, build and
test commands, style, testing, and security guidance. It also supports nested
files when a subdirectory needs more specific instructions.

Keep it concise and operational. It should contain:

- One-paragraph purpose
- Required reading order
- Repository map
- Architectural invariants
- Exact setup, test, lint, docs, and dummy-app commands
- TDD and migration expectations
- Public API compatibility rule
- Documentation update matrix
- Security constraints
- Commit/release conventions

It should link to detailed documents rather than repeat them.

Reference: [AGENTS.md open format](https://agents.md/)

### 2. `README.md`: human installation and first success

The README is the gem consumer's front door. RubyGems identifies README plus
inline code documentation as the usual gem documentation structure.

The README should contain:

- What the gem does
- A short workflow diagram
- Compatibility table
- Five-minute installation
- Open/no-auth initializer example
- Authenticated initializer example
- How to open the review UI
- How to create/copy/download an export
- How to run the doctor
- Links to detailed docs

Do not turn the README into the complete architecture reference.

References:

- [RubyGems gem structure](https://guides.rubygems.org/what-is-a-gem/)
- [RubyGems specification metadata](https://guides.rubygems.org/specification-reference/)

### 3. `docs/`: durable design and workflow sources of truth

Create:

```text
docs/
├── WHY.md
├── ARCHITECTURE.md
├── WORKFLOW.md
├── PUBLIC_API.md
├── INSTALLATION.md
├── DEVELOPMENT.md
├── TESTING.md
├── SECURITY.md
├── IMPLEMENTATION_PLAN.md
└── decisions/
    ├── 0001-isolated-mountable-engine.md
    ├── 0002-host-integration-callbacks.md
    ├── 0003-export-batches-and-fingerprints.md
    ├── 0004-importmap-and-stimulus-integration.md
    └── 0005-open-default-authorization.md
```

Document responsibilities:

- `WHY.md`: purpose, audience, principles, non-goals.
- `ARCHITECTURE.md`: components, dependencies, request/data flow, boundaries.
- `WORKFLOW.md`: capture, review, and export state machines and UX.
- `PUBLIC_API.md`: initializer settings, callbacks, helpers, formatter contract,
  model extension surface, commands, routes.
- `INSTALLATION.md`: new install, no-auth, custom auth, upgrades, uninstall.
- `DEVELOPMENT.md`: repository layout, dummy app, local development.
- `TESTING.md`: commands, test layers, compatibility matrix.
- `SECURITY.md`: CSRF, authorization, iframe/path constraints, escaping.
- `IMPLEMENTATION_PLAN.md`: copy of this actionable plan, updated as built.
- `decisions/`: short ADRs explaining why durable choices were made.

### 4. Inline YARD/RDoc: public Ruby API only

Document public configuration methods, callbacks, helpers, model methods, and
formatter contracts inline. Do not document every private method. Configure the
gemspec's `documentation_uri`, `source_code_uri`, and `changelog_uri` metadata.

### 5. CLI/generator help: executable discovery

CLI help should explain things an agent or user can execute:

- Generator purpose and options
- Doctor purpose and output formats
- Migration task
- Version
- Paths to installed documentation

It should not be the canonical architecture explanation. Architecture changes
more richly than a help screen can express, and duplicating it there invites
drift.

Required discovery surfaces:

```bash
bin/rails generate page_feedback:install --help
bin/rails --tasks | grep page_feedback
bin/rails page_feedback:doctor
PAGE_FEEDBACK_FORMAT=json bin/rails page_feedback:doctor
bundle exec page_feedback help
bundle exec page_feedback docs
bundle exec page_feedback version
```

The standalone executable is intentionally small. `docs` prints the installed
gem root and curated documentation paths. `doctor` may delegate to the same
diagnostic object used by the Rails task.

### 6. `llms.txt`: only when there is a documentation website

Do not use a repository-root `llms.txt` as a replacement for `AGENTS.md`. The
`llms.txt` proposal targets `/llms.txt` at a website root and acts as a curated
manifest of LLM-readable web documentation URLs.

When a documentation site exists, publish:

- `/llms.txt` — concise links to Markdown documentation
- `/llms-full.txt` — generated combined context, if useful

Generate both from canonical docs; never maintain duplicate prose manually.

Reference: [llms.txt proposal](https://llmstxt.org/)

### Documentation update matrix

| Change | Required documentation |
|---|---|
| New configuration option | `PUBLIC_API.md`, initializer template, inline docs |
| Changed install step | `README.md`, `INSTALLATION.md`, generator help, doctor |
| Changed workflow/state | `WORKFLOW.md`, `ARCHITECTURE.md`, tests |
| Durable architecture decision | New/amended ADR, `ARCHITECTURE.md` |
| New maintenance command | `AGENTS.md`, `DEVELOPMENT.md`, CLI help |
| Security behavior | `SECURITY.md`, initializer comments, tests |
| Public behavior change | `CHANGELOG.md`, relevant docs, version decision |

## Proposed Repository Layout

```text
page_feedback/
├── .github/workflows/ci.yml
├── AGENTS.md
├── CHANGELOG.md
├── Gemfile
├── LICENSE.txt
├── README.md
├── Rakefile
├── page_feedback.gemspec
├── app/
│   ├── assets/
│   │   ├── javascripts/page_feedback/
│   │   │   ├── controllers/capture_controller.js
│   │   │   ├── context_recorder.js
│   │   │   ├── element_capture.js
│   │   │   ├── feedback_picker.js
│   │   │   ├── review_highlight.js
│   │   │   └── clipboard.js
│   │   └── stylesheets/page_feedback/page_feedback.css
│   ├── controllers/page_feedback/
│   │   ├── application_controller.rb
│   │   ├── comments_controller.rb
│   │   └── review/
│   │       ├── base_controller.rb
│   │       ├── pages_controller.rb
│   │       ├── pages/comments_controller.rb
│   │       ├── comments_controller.rb
│   │       ├── comments/approvals_controller.rb
│   │       ├── comments/rejections_controller.rb
│   │       ├── bulk_approvals_controller.rb
│   │       ├── bulk_rejections_controller.rb
│   │       └── exports_controller.rb
│   ├── helpers/page_feedback/application_helper.rb
│   ├── models/page_feedback/
│   │   ├── application_record.rb
│   │   ├── comment.rb
│   │   ├── export.rb
│   │   └── export_item.rb
│   └── views/page_feedback/
│       ├── layouts/application.html.erb
│       ├── comments/
│       ├── review/pages/
│       ├── review/pages/comments/
│       ├── review/comments/
│       └── review/exports/
├── config/
│   ├── importmap.rb
│   ├── locales/page_feedback.en.yml
│   └── routes.rb
├── db/migrate/
├── docs/
├── exe/page_feedback
├── lib/
│   ├── page_feedback.rb
│   ├── page_feedback/configuration.rb
│   ├── page_feedback/diagnostics.rb
│   ├── page_feedback/engine.rb
│   ├── page_feedback/exporters/markdown.rb
│   ├── page_feedback/generators/install_generator.rb
│   ├── page_feedback/version.rb
│   └── tasks/page_feedback_tasks.rake
├── sig/page_feedback.rbs
└── spec/
    ├── dummy/
    ├── models/
    ├── requests/
    ├── system/
    ├── javascript/
    ├── generators/
    └── lib/
```

`sig/page_feedback.rbs` covers the small public configuration and formatter
surface. It is not required to type all Rails internals.

## Runtime Component Flow

```text
Host layout helpers
  ├─ page_feedback_head
  │    ├─ engine CSS
  │    └─ review-highlight module
  └─ page_feedback_widget
       └─ capture Stimulus controller
              │
              ▼
     PageFeedback::CommentsController#create
              │
              ▼
       PageFeedback::Comment (pending)
              │
              ▼
       Review page queue + iframe replay
              │
       ┌──────┴──────┐
       ▼             ▼
    approval      rejection
       │
       ▼
 approved current revisions
       │
       ▼
 PageFeedback::Export + ExportItems
       │
       ├─ stored Markdown snapshot
       ├─ copy to clipboard
       └─ download .md
```

## Public Ruby API

### Module configuration

```ruby
module PageFeedback
  class << self
    attr_reader :configuration

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
```

`reset_configuration!` is public primarily for tests.

### Configuration object

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(_controller) { nil }
  config.capture_authorizer = ->(_controller) { true }
  config.review_authorizer = ->(_controller) { true }

  config.actor_label = ->(actor) {
    actor.respond_to?(:email) ? actor.email : actor.to_s
  }

  config.categories = {
    "bug" => "Bug",
    "idea" => "Idea",
    "question" => "Question",
    "compliment" => "Compliment"
  }
  config.default_category = "idea"

  config.activation_shortcut = { alt: true, key: "f" }
  config.ignored_css_classes = []

  config.source_locator = ->(_comment) { nil }
  config.export_formatter = PageFeedback::Exporters::Markdown
end
```

Configuration rules:

- Callback arguments are engine controller instances.
- Authorization callbacks return truthy/falsey values.
- `current_actor` returns any persisted Active Record model or `nil`.
- The engine never accepts actor IDs from request parameters.
- `categories` keys are stored values; labels are presentation values.
- Changing/removing stored category keys is a data migration concern.
- `source_locator` returns a source path string or `nil`.
- `export_formatter` responds to `.call(comments:, generated_at:)` and returns
  a UTF-8 string.
- Configuration is finalized during boot and should not mutate per request.

### Open/no-auth initializer

This is the generated default:

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(_controller) { nil }
  config.capture_authorizer = ->(_controller) { true }
  config.review_authorizer = ->(_controller) { true }
end
```

The initializer comments must clearly state that review is open.

### Authenticated host initializer

For the source Diagnostic Engine application:

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(controller) {
    controller.send(:current_user)
  }

  config.capture_authorizer = ->(controller) {
    controller.send(:logged_in?)
  }

  config.review_authorizer = ->(controller) {
    controller.send(:admin?)
  }

  config.ignored_css_classes = %w[
    revealed
    scene-visible
    cf-metric-fill--animate
    cf-copilot-mock--slide-in
  ]

  config.source_locator = ->(comment) {
    {
      "case_file#show" => "app/views/case_file/show.html.erb",
      "disturbances#index" => "app/views/disturbances/index.html.erb",
      "disturbances#show" => "app/views/disturbances/show.html.erb",
      "search#index" => "app/views/search/index.html.erb"
    }[comment.controller_action]
  }
end
```

### View helper API

```erb
<head>
  <%= page_feedback_head %>
</head>

<body>
  <%= page_feedback_widget %>
  <%= yield %>
</body>
```

- `page_feedback_head` emits the namespaced stylesheet and replay-highlighter
  module tags once.
- `page_feedback_widget` emits the capture root, modal, and toast target.
- The widget helper returns an empty safe string when capture is unauthorized.
- In replay mode it suppresses capture UI while leaving highlighting available.
- Server endpoints independently enforce authorization.

### Formatter contract

```ruby
module PageFeedback
  module Exporters
    class Markdown
      def self.call(comments:, generated_at:)
        new(comments:, generated_at:).render
      end
    end
  end
end
```

Custom formatter example:

```ruby
class MyFormatter
  def self.call(comments:, generated_at:)
    # Return a UTF-8 String. Do not persist or mutate comments here.
  end
end

PageFeedback.configure do |config|
  config.export_formatter = MyFormatter
end
```

The export model, not the formatter, owns persistence and membership.

## Persistence Model

Use database-neutral Rails column types so the default SQLite dummy application
and PostgreSQL hosts both work. Use `t.json`, not PostgreSQL-only `jsonb`.

### `page_feedback_comments`

```ruby
create_table :page_feedback_comments do |t|
  t.string :status, null: false, default: "pending"
  t.string :category, null: false, default: "idea"

  t.text :comment_text, null: false
  t.text :refined_text
  t.text :reviewer_notes

  t.string :page_path, null: false
  t.string :page_title
  t.string :controller_action
  t.text :css_selector
  t.text :element_html
  t.json :context, null: false, default: {}

  t.string :submitter_type
  t.bigint :submitter_id
  t.string :reviewed_by_type
  t.bigint :reviewed_by_id

  t.datetime :approved_at
  t.datetime :rejected_at

  t.timestamps
end
```

Indexes:

- `status`
- `category`
- `page_path`
- `created_at`
- `[submitter_type, submitter_id]`
- `[reviewed_by_type, reviewed_by_id]`

Associations:

```ruby
belongs_to :submitter, polymorphic: true, optional: true
belongs_to :reviewed_by, polymorphic: true, optional: true
has_many :export_items, dependent: :restrict_with_error
has_many :exports, through: :export_items
```

Statuses are `pending`, `approved`, and `rejected`. Export is not a review
status.

### Normalized context shape

```json
{
  "parent_html": "<section>...</section>",
  "viewport": "1440x900",
  "scroll_y": 812,
  "console_errors": [
    { "message": "Failed to fetch", "timestamp_ms": 1786190123456 }
  ],
  "navigation_history": [
    { "url": "/projects/42", "timestamp_ms": 1786190123000 }
  ]
}
```

Normalize incoming camelCase/legacy keys at the controller boundary. Persist
snake_case keys only.

### `page_feedback_exports`

```ruby
create_table :page_feedback_exports do |t|
  t.string :format, null: false, default: "markdown"
  t.string :label
  t.text :body, null: false
  t.string :body_digest, null: false
  t.string :created_by_type
  t.bigint :created_by_id
  t.timestamps
end
```

Indexes:

- `created_at`
- `[created_by_type, created_by_id]`
- unique `body_digest` is not required; repeated intentional exports are valid

### `page_feedback_export_items`

```ruby
create_table :page_feedback_export_items do |t|
  t.references :export, null: false,
    foreign_key: { to_table: :page_feedback_exports }
  t.references :comment, null: false,
    foreign_key: { to_table: :page_feedback_comments }
  t.string :comment_fingerprint, null: false
  t.integer :position, null: false
  t.timestamps
end
```

Indexes:

- unique `[export_id, comment_id]`
- `[comment_id, comment_fingerprint]`

### Comment export fingerprint

The fingerprint is a SHA-256 digest over a canonical JSON representation of
fields that affect exported output:

- category
- effective text
- reviewer notes
- page path
- page title
- controller/action
- CSS selector
- selected element HTML
- resolved source location

Do not include database timestamps or actor labels. A reviewer edit changes the
fingerprint; an unrelated `updated_at` touch does not.

Derived export state:

```text
never_exported
  no export item exists for the comment

exported
  an export item exists with the current fingerprint

changed_since_export
  export items exist, but none match the current fingerprint
```

Only approved comments whose current fingerprint has not been exported are
`ready_for_export`.

## Domain Methods and Scopes

### `PageFeedback::Comment`

Public domain methods:

```ruby
comment.pending?
comment.approved?
comment.rejected?
comment.effective_text
comment.approve!(reviewer: nil)
comment.reject!(reviewer: nil)
comment.return_to_pending!(reviewer: nil)
comment.export_fingerprint
comment.export_state
comment.ready_for_export?
```

Transitions run in one update and maintain timestamp consistency:

- Approve sets `status=approved`, `approved_at=now`, clears `rejected_at`.
- Reject sets `status=rejected`, `rejected_at=now`, clears `approved_at`.
- Return to pending clears both decision timestamps.
- All three set `reviewed_by` to the supplied reviewer, including `nil`.

Scopes:

```ruby
PageFeedback::Comment.pending
PageFeedback::Comment.approved
PageFeedback::Comment.rejected
PageFeedback::Comment.by_category(category)
PageFeedback::Comment.for_page(path)
PageFeedback::Comment.recent
PageFeedback::Comment.ready_for_export
```

### `PageFeedback::Export`

Creation API:

```ruby
PageFeedback::Export.create_from!(
  comments: PageFeedback::Comment.ready_for_export,
  actor: current_actor,
  formatter: PageFeedback.configuration.export_formatter,
  label: nil
)
```

`create_from!` must:

1. Materialize and lock the selected approved comments.
2. Recheck readiness inside the transaction.
3. Resolve source locations.
4. Render one body.
5. Persist the export snapshot.
6. Persist ordered items with their current fingerprints.
7. Commit atomically.

An export is immutable after creation. Do not provide update or destroy routes
in v1. An optional immutable label makes provenance such as a reconstructed
legacy-import snapshot visible in history without changing snapshot semantics.

## Review and Export State Machines

### Review state

```text
                approval
pending ─────────────────────► approved
   │                              │
   │ rejection                    │ rejection
   ▼                              ▼
rejected ◄──────────────────── approved
   │                              │
   └────── approval ──────────────┘

approved/rejected ── return to pending ──► pending
```

Approval or rejection is a domain transition represented as a REST resource.
It is not an arbitrary custom controller action.

### Export freshness

```text
approved + no export item
  → Ready to export

approved + matching fingerprint export item
  → Exported

approved + only stale fingerprint export items
  → Changed since export / Ready to export again

pending or rejected
  → Not exportable
```

## Engine Routes and Controllers

Use only REST actions. Avoid the source application's custom actions such as
`approve`, `reject`, `batch_action`, `mark_all_exported`, `copy_markdown`, and
`export_preview` on one large controller.

Proposed `config/routes.rb`:

```ruby
PageFeedback::Engine.routes.draw do
  resources :comments, only: :create

  namespace :review do
    root "pages#index"

    resources :pages, param: :key, only: :index do
      resources :comments, only: :index, module: :pages
    end

    resources :comments, only: %i[show update] do
      resource :approval, only: %i[create destroy], module: :comments
      resource :rejection, only: %i[create destroy], module: :comments
    end

    resources :bulk_approvals, only: :create
    resources :bulk_rejections, only: :create
    resources :exports, only: %i[index new create show]
  end
end
```

Controller responsibilities:

| Controller | Actions | Responsibility |
|---|---|---|
| `CommentsController` | `create` | Authorize capture, resolve actor, normalize and persist feedback, Turbo/HTML/JSON response |
| `Review::PagesController` | `index` | Page-grouped queue and counts |
| `Review::Pages::CommentsController` | `index` | Filtered per-page queue, current/previous/next item |
| `Review::CommentsController` | `show`, `update` | Detail and reviewer-editable text/notes |
| `Review::Comments::ApprovalsController` | `create`, `destroy` | Approve or return an approval to pending |
| `Review::Comments::RejectionsController` | `create`, `destroy` | Reject or return a rejection to pending |
| `Review::BulkApprovalsController` | `create` | Approve selected pending/rejected comments |
| `Review::BulkRejectionsController` | `create` | Reject selected pending/approved comments |
| `Review::ExportsController` | `index`, `new`, `create`, `show` | History, preview, immutable snapshot creation, HTML/Markdown representation |

Authorization:

- `PageFeedback::ApplicationController < ::ApplicationController` so global host
  authentication filters and request context remain available.
- Capture uses `ensure_capture_authorized` on `CommentsController#create`.
- `Review::BaseController` uses `ensure_review_authorized` for all review routes.
- Failed authorization returns `403 Forbidden` for every format.
- The UI may hide unavailable actions, but server checks are authoritative.
- Default callbacks allow access, satisfying no-auth host applications.

## Capture Contract

### Trigger and selection

- Alt+F toggles capture mode by default.
- Escape exits capture mode or closes the modal.
- Ctrl+Enter submits from the comment textarea.
- Hover outlines the prospective target.
- Click prevents the target's ordinary behavior and opens the modal.
- Skip the gem UI and interactive controls (`nav`, `form`, `input`, `textarea`,
  `select`, `button`) including descendants.
- Exclude configured runtime classes from generated selectors.

### Client-side limits

- Selected outer HTML: 2,000 characters.
- Parent outer HTML: 1,000 characters.
- Console errors: latest 10.
- Navigation events: latest 5.
- Selector preview: 80 characters.
- Element preview: 300 characters.

These preserve the source behavior. Add corresponding server-side maximums so
the limits cannot be bypassed by direct requests. Server limits may be slightly
higher to allow encoded form overhead.

### Submission fields

```text
comment_text
category
page_path
page_title
controller_action
css_selector
element_html
context[parent_html]
context[viewport]
context[scroll_y]
context[console_errors]
context[navigation_history]
```

`page_path` comes from `window.location.pathname`; omit query strings and
fragments.

### Response formats

- Turbo success: `201 Created`, replace modal with fresh closed form, append
  transient success toast.
- Turbo validation failure: `422`, reopen populated form and append error toast.
- HTML success: redirect back.
- HTML validation failure: render a usable error response.
- JSON success: `201` with `{ id, status }`.
- JSON failure: `422` with validation errors.

Keep CSRF protection enabled for browser and JSON session requests.

## Browser and Asset Integration

### Importmap

The engine appends its own importmap file during initialization:

```ruby
initializer "page_feedback.importmap", before: "importmap" do |app|
  app.config.importmap.paths << Engine.root.join("config/importmap.rb")
  app.config.importmap.cache_sweepers << Engine.root.join("app/assets/javascripts")
end
```

The engine pins modules under `page_feedback/*`.

### Stimulus proxy

The host's standard Stimulus eager loader discovers controllers from its own
`app/javascript/controllers`. The installer creates small proxy files rather
than starting a second Stimulus application:

```javascript
// app/javascript/controllers/page_feedback_capture_controller.js
export { default } from "page_feedback/controllers/capture_controller"
```

The capture markup uses `data-controller="page-feedback-capture"`.

If the standard host controller loader is absent, the generator must stop
short of silently guessing and print the manual registration instructions.

### CSS

Ship browser-ready CSS through Propshaft. Prefix selectors and variables:

```css
--page-feedback-background
--page-feedback-surface
--page-feedback-text
--page-feedback-muted
--page-feedback-accent
--page-feedback-success
--page-feedback-warning
--page-feedback-error
--page-feedback-border
```

All variables have standalone defaults. Host apps may override them without
rewriting engine CSS. Do not rely on `.main-content`, host typography, or
generic classes such as `.badge`, `.btn`, `.modal`, or `.review-ui`.

### Review replay

- Store and replay only local paths beginning with one `/` and not `//`.
- Add engine-specific query parameters for selector and scroll position.
- In replay mode the host helper suppresses capture chrome.
- The replay module catches invalid/stale selectors without breaking the page.
- The iframe is sandboxed and visually noninteractive.
- Never construct a replay iframe from an external URL.

## Review UX Contract

### Page overview

Show one row per `page_path` with:

- Latest page title
- Path
- Newest comment time
- Pending count
- Approved/ready count
- Exported-current count
- Changed-since-export count
- Rejected count
- Category counts

Primary filters:

```text
Pending | Ready to export | Exported | Changed | Rejected | All
```

Category filtering remains available.

### Per-page queue

- Iframe on the left, review sidebar on the right.
- Highlight the stored selector and restore approximate scroll position.
- Show queue position and previous/next navigation.
- Show category, submitter label when present, original comment, page title,
  selector, and captured context.
- Permit reviewer notes and refined text.
- Approve/reject submissions save reviewer edits in the same request.
- Automatically advance to the next item when appropriate.
- Show full detail link and export readiness.

### Export UI

- `Review::ExportsController#new` previews selected ready comments.
- `create` persists an immutable export and redirects to `show`.
- `show` displays membership, creator, time, format, stored body, and actions.
- Copy copies the stored `body`; it does not re-render current comments.
- Download serves the same stored body as `.md`.
- Export history links back to included comments.
- Comment badges link to matching exports where useful.

## Default Markdown Contract

Group comments by page path, then by CSS selector. Page-level comments precede
selector-specific comments. Sort selector groups by category priority:

```text
bug → question → idea → compliment
```

Example:

````markdown
# Feedback Export

Generated: 2026-08-08 14:30 CEST

## /projects/42

Source: `app/views/projects/show.html.erb`

### `.project-summary` — [bug] [idea]

- [bug] Validation failures are not visible after saving.
  - Reviewer note: Preserve the inline editing flow.
- [idea] Show the last successful save time.

**Current HTML:**

```html
<section class="project-summary">...</section>
```
````

Use `effective_text` (refined text when present, otherwise original). Escape or
fence Markdown safely so captured HTML and user text cannot corrupt document
structure accidentally.

## Install Generator Contract

Command:

```bash
bin/rails generate page_feedback:install [options]
```

Options:

```text
--mount-path=/feedback
--skip-route
--skip-layout
--skip-stimulus
--force
```

Behavior:

1. Create initializer with open defaults and authenticated examples in comments.
2. Mount the engine unless skipped or already mounted.
3. Locate the host application layout and add head/widget helpers idempotently.
4. Create the Stimulus proxy controller idempotently.
5. Print the migration install and database migration commands.
6. Print the review URL and doctor command.
7. Never overwrite customized files without `--force` and a visible diff.
8. Support `rails destroy page_feedback:install` for generated host files where
   safe; do not remove user migrations or data automatically.

The `--help` text includes purpose, generated files, options, examples, and the
open-review warning.

## Diagnostics and CLI Contract

Use one `PageFeedback::Diagnostics` object for the Rake task and executable.

Checks:

- Gem and Rails versions
- Supported Rails/Importmap/Turbo/Stimulus/Propshaft dependencies loaded
- Engine mount present and mount path
- Initializer present
- Configuration callbacks callable
- Whether capture/review callbacks are still open defaults
- Engine migrations installed
- Migrations pending
- Tables present
- Host head/widget helper integration detected where practical
- Stimulus proxy present
- Engine assets resolvable
- Default category exists in configured categories
- Export formatter contract valid
- Documentation paths

Human output:

```text
PageFeedback 0.1.0
Rails 8.1.3.1

PASS  Engine mounted at /feedback
PASS  Database tables present
PASS  Capture controller proxy installed
WARN  Review authorization is open
PASS  Markdown formatter responds to .call

Review: http://localhost:3000/feedback/review/pages
Docs:   /path/to/page_feedback/docs
```

JSON output has stable keys and nonzero exit status on failures:

```json
{
  "version": "0.1.0",
  "ok": true,
  "checks": [
    { "name": "engine_mount", "status": "pass", "details": "/feedback" }
  ]
}
```

Warnings do not make `ok` false. Missing required integration does.

## Security Invariants

Even for a personal-use gem:

- Do not disable CSRF protection.
- Never accept submitter/reviewer/exporter identity from request params.
- Enforce authorization in controllers for every response format.
- Return `403` for denied access.
- Escape feedback, reviewer notes, selectors, paths, context, and captured HTML
  in engine HTML views.
- Render captured HTML as text, never `html_safe`.
- Permit replay only for validated local paths.
- Do not store query strings or fragments.
- Bound request field sizes server-side.
- Treat configured callbacks as trusted host code.
- Keep the open default explicit in generated docs and doctor output.

## Testing Strategy

Use RSpec, FactoryBot, Rails system tests driven through Capybara, and focused
JavaScript unit tests. The engine dummy application is the integration host.

### Model tests

- Comment validations and normalized status/category behavior
- Polymorphic actor associations with and without host user
- Every review transition and timestamp clearing
- Effective text
- Fingerprint stability and change detection
- Export state derivation
- Ready-for-export scope
- Export atomic creation and immutable body
- Duplicate/repeated export behavior
- Export item ordering and membership

### Request tests

- Anonymous and actor-attributed capture
- Capture/review allow and deny callbacks
- Turbo, HTML, and JSON capture success/failure
- CSRF behavior
- Context normalization and malformed arrays
- Local path validation
- Page grouping and filters
- Queue navigation
- Reviewer updates
- Approval/rejection/reset resources
- Bulk resources
- Export preview/create/show/index
- `.md` response uses stored body
- Stale export becomes ready after comment edit

### JavaScript tests

- Selector generation
- Configured dynamic-class stripping
- Skip-element behavior
- HTML caps
- Alt+F/Escape/Ctrl+Enter behavior
- Console error ring buffer
- Navigation history ring buffer
- Modal hidden-field population
- Stale/invalid replay selector behavior
- Clipboard success/fallback/failure

### System tests

1. Install/open dummy app and capture feedback with Alt+F.
2. Capture as anonymous user.
3. Capture as dummy authenticated user and verify attribution.
4. Review the comment against the iframe highlight.
5. Refine and approve it.
6. Verify `Ready to export`.
7. Create an export and verify `Exported`.
8. Edit reviewer text and verify `Changed since export`.
9. Re-export and verify current state is exported again.
10. Reject and restore feedback through UI resources.

### Generator/diagnostic tests

- Fresh Rails 8 dummy installation
- Idempotent second install
- Custom mount path
- Skip options
- Destroy behavior
- Missing layout/controller loader messaging
- Doctor pass/warn/fail and JSON schema

### Compatibility matrix

Minimum declared compatibility:

- Ruby `>= 3.2`
- Rails `>= 8.0`, `< 9.0`
- Importmap, Turbo, Stimulus, Propshaft

Test at least:

- Current Ruby 3.4 + Rails 8.1
- Lowest supported Ruby/Rails combination
- SQLite dummy app
- Diagnostic Engine PostgreSQL adoption before extraction is declared complete

## Implementation Phases

Each phase ends with a scoped commit and push. Do not proceed past a failing
automated gate.

### Phase 0 — Scaffold and documentation spine

Create the mountable engine, gemspec, RSpec dummy app, CI skeleton, AGENTS.md,
README, docs listed above, ADR skeletons, and changelog.

Automated verification:

- [x] `bundle exec rake spec` boots the dummy app.
- [x] `bundle exec rubocop` passes.
- [x] `gem build page_feedback.gemspec` succeeds.
- [x] All gemspec files include README, docs, migrations, assets, executable.
- [x] Documentation links have no missing local targets.

Manual verification:

- [x] A fresh LLM reading only `AGENTS.md` can identify purpose, required docs,
  repository map, and exact validation commands.

### Phase 1 — Configuration and engine boundary

Implement configuration defaults/callback contracts, isolated engine, host
controller inheritance, importmap composition, helper stubs, and authorization
predicates.

Automated verification:

- [x] Open defaults return nil actor and permit capture/review.
- [x] Custom callbacks receive the current engine controller.
- [x] Denied authorization returns 403.
- [x] Importmap exposes engine modules.
- [x] Configuration public API matches RBS and YARD docs.

### Phase 2 — Persistence and domain state

Add comments, exports, export items, migrations, associations, validations,
transitions, fingerprints, export-state derivation, and factories.

Automated verification:

- [x] Migrations run on the SQLite dummy app.
- [x] Anonymous and polymorphic actor records persist.
- [x] State transition suite passes.
- [x] Fingerprint/export-state suite passes.
- [x] Export creation is transactional and immutable.

### Phase 3 — Capture backend and host helpers

Implement `CommentsController#create`, parameter/context normalization,
authorization, format responses, modal/toast partials, and head/widget helpers.

Automated verification:

- [x] Turbo/HTML/JSON request specs pass.
- [x] CSRF remains enabled.
- [x] Submitted actor params cannot spoof attribution.
- [x] Invalid paths and oversized fields are rejected.
- [x] Unauthorized widget is omitted and unauthorized POST is forbidden.

### Phase 4 — Browser capture assets

Port and namespace element capture, feedback picker, context recorder, Stimulus
controller, review highlighter, and CSS.

Automated verification:

- [x] JavaScript unit suite passes.
- [x] Propshaft resolves and fingerprints assets.
- [x] Importmap resolves all module imports.
- [x] CSS selectors/variables are fully namespaced.

Manual verification:

- [ ] Alt+F selection feels equivalent to the source app.
- [ ] Modal and toast are legible on both light and dark host pages.

### Phase 5 — Review queue and decisions

Implement page overview, nested page queue, iframe replay, comment detail/update,
approval/rejection/reset resources, bulk resources, filters, and navigation.

Automated verification:

- [x] Review request suite passes.
- [x] Review authorization covers every route.
- [x] Iframe paths cannot be external.
- [x] Queue redirects preserve filters and next item.
- [x] System test completes anonymous capture through approval.

### Phase 6 — Export batches and generic Markdown

Implement formatter, export preview/create/history/show, clipboard, `.md`
download, fingerprints, and UI badges/filters.

Automated verification:

- [x] Stored export body equals downloaded/copied body.
- [x] Export item membership and ordering are deterministic.
- [x] Never-exported/exported/changed states are correct.
- [x] Custom formatter contract works.
- [x] Concurrent creation cannot export an invalid comment revision silently.

Manual verification:

- [ ] Markdown is useful as direct input to a coding LLM.
- [ ] Review UI makes exported state understandable without explanation.

### Phase 7 — Installer, doctor, and executable

Implement generator, Rake tasks, diagnostics, standalone executable, help text,
idempotence, and JSON output.

Automated verification:

- [x] Install generator suite passes.
- [x] Re-running install makes no duplicate changes.
- [x] Doctor detects every intentionally broken fixture.
- [x] JSON output schema is stable.
- [x] `--help`, `docs`, and `version` exit successfully.

Manual verification:

- [ ] A new Rails 8 app can be installed using only README commands.
- [ ] An LLM can diagnose a deliberately incomplete install from doctor output.

### Phase 8 — Diagnostic Engine adoption

Integrate the path/git gem into `/home/sander/Projects/diagnostic-engine`, migrate
existing data, establish feature parity, then remove the in-app implementation.

Adoption sequence:

1. Add the gem by local path during development.
2. Run installer and migrations.
3. Configure current actor, capture/review authorization, ignored classes, and
   source locator as shown above.
4. Add a one-time data migration:
   - `pending` → `pending`
   - `approved` → `approved`, no export item
   - `rejected` → `rejected`
   - legacy `exported` → `approved` plus membership in one clearly labeled
     legacy-import export snapshot
5. Copy all comment fields and normalize context keys.
6. Run both systems only in test/staging long enough to verify counts and output.
7. Switch layout/routes/navigation to the engine.
8. Remove old models, controllers, views, JS, CSS, routes, and migrations only
   after data and behavior verification.

Automated verification:

- [ ] Counts match by legacy status/category/page.
- [ ] Every legacy exported record belongs to a legacy export.
- [ ] Existing review/capture behavior is covered through engine routes.
- [ ] Diagnostic Engine full test suite passes.
- [ ] No old page-comment constants/routes/assets remain.

Manual verification:

- [ ] Production-like login permits capture and admin-only review.
- [ ] Existing feedback replays and exports correctly.

### Phase 9 — Release readiness

Finalize version `0.1.0`, changelog, gem metadata, packaged docs, release task,
and install from the built `.gem` rather than a source path.

Automated verification:

- [ ] Clean checkout passes all checks.
- [ ] Built gem installs into a fresh Rails 8 app.
- [ ] Packaged gem contains all runtime assets/docs/migrations.
- [ ] `page_feedback:doctor` passes in the packaged install.
- [ ] CI compatibility matrix passes.

## Global Acceptance Criteria

The gem is complete when:

- [ ] A fresh Rails 8 Importmap application installs it without copying feature
  implementation code.
- [ ] No-auth capture and review work with null actor associations.
- [ ] Authenticated hosts can attribute actors and authorize through initializer
  callbacks.
- [ ] Alt+F capture retains current rich context behavior.
- [ ] Review is page-grouped and replays the selected element.
- [ ] Review status and export state are separate and correctly visible.
- [ ] Exports are immutable snapshots with exact membership.
- [ ] Changed-since-export feedback becomes ready again.
- [ ] Default Markdown is vendor-neutral and coding-agent-friendly.
- [ ] A custom formatter can replace Markdown rendering without changing domain
  persistence.
- [ ] Generator help and doctor output are accurate.
- [ ] `AGENTS.md` routes coding agents to canonical docs and commands.
- [ ] README gets a human to first success quickly.
- [ ] Public APIs have inline and long-form documentation.
- [ ] Diagnostic Engine can replace its local implementation with the gem.

## Architectural Invariants

Future implementation and maintenance agents must preserve these unless a new
decision explicitly replaces them:

1. The host application is in control; the engine enhances it.
2. All engine classes, routes, tables, assets, selectors, and variables are
   namespaced.
3. Authentication is optional; authorization is callback-driven and enforced
   server-side.
4. Request parameters never choose actor identity.
5. Review status is independent from export history.
6. Exports are immutable snapshots.
7. Export freshness is based on meaningful content fingerprints.
8. Formatters render; domain models persist and transition.
9. Controllers use REST resources and remain small.
10. CSRF protection stays enabled.
11. Replay paths stay same-origin and local.
12. Canonical docs are not duplicated into CLI help or generated LLM files.
13. `AGENTS.md` is a map and operating manual, not the whole product manual.
14. Any future `llms.txt` is generated for a documentation website.

## Initial Prompt for a Fresh Coding Agent

Use this after copying the blueprint into the new repository:

> Build the `page_feedback` gem described in
> `docs/IMPLEMENTATION_PLAN.md`. Read that file completely, then create and read
> the root `AGENTS.md` and the documentation files required by Phase 0. Implement
> only Phase 0 first using small commits and red-green TDD where code is involved.
> Run every Phase 0 automated verification command, report evidence, and stop for
> review before Phase 1. The public API, state machines, routes, documentation
> responsibilities, and architectural invariants in the plan are binding. Do not
> introduce Rails 7, non-Importmap JavaScript, multi-tenancy, notifications,
> external services, or vendor-specific AI behavior.

## Research References

- [AGENTS.md open format](https://agents.md/)
- [llms.txt proposal](https://llmstxt.org/)
- [RubyGems gem structure](https://guides.rubygems.org/what-is-a-gem/)
- [RubyGems specification reference](https://guides.rubygems.org/specification-reference/)
- [Rails plugins](https://guides.rubyonrails.org/plugins.html)
- [Rails engines](https://guides.rubyonrails.org/engines.html)
- [Importmap composition](https://github.com/rails/importmap-rails#composing-import-maps)
