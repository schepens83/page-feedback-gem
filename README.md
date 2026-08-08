# PageFeedback

PageFeedback is an isolated Rails 8 engine for turning feedback on rendered
pages into precise, reviewable work. A user selects an element with Alt+F, a
reviewer refines and decides the feedback in context, and approved revisions are
collected into immutable Markdown exports.

```text
host page → capture → pending review → approved revision → immutable export
```

> **Status:** early implementation. The installation commands below describe
> the intended public workflow and will become executable phase by phase.

Open [the standalone Phase 0 report](page-feedback.html) for an easy-to-scan,
printable view of the current outcome, verification evidence, and roadmap.

## Compatibility

| Component | Supported |
|---|---|
| Ruby | 3.2 or newer |
| Rails | 8.0 or newer, below 9.0 |
| JavaScript | Importmap + Stimulus + Turbo |
| Assets | Propshaft |
| Database | SQLite and PostgreSQL through portable Rails types |

## Five-minute installation

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

The generated initializer is deliberately open by default:

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(_controller) { nil }
  config.capture_authorizer = ->(_controller) { true }
  config.review_authorizer = ->(_controller) { true }
end
```

For an authenticated host, connect the engine to existing controller methods:

```ruby
PageFeedback.configure do |config|
  config.current_actor = ->(controller) { controller.send(:current_user) }
  config.capture_authorizer = ->(controller) { controller.send(:logged_in?) }
  config.review_authorizer = ->(controller) { controller.send(:admin?) }
end
```

Open `/feedback/review/pages` to review captured feedback. The export screen
previews ready comments, stores an exact Markdown snapshot, and lets reviewers
copy or download that stored body.

## Documentation

- [Why this exists](docs/WHY.md)
- [Installation and upgrades](docs/INSTALLATION.md)
- [Workflow and state](docs/WORKFLOW.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Public API](docs/PUBLIC_API.md)
- [Security model](docs/SECURITY.md)
- [Development](docs/DEVELOPMENT.md)
- [Testing](docs/TESTING.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)

The project is not yet released, and its license remains undecided.
