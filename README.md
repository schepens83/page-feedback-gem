# PageFeedback

PageFeedback is an isolated Rails 8 engine for turning feedback on rendered
pages into precise, reviewable work. A user selects an element with Alt+F, a
reviewer refines and decides the feedback in context, and approved revisions are
collected into immutable Markdown exports.

```text
host page → capture → pending review → approved revision → immutable export
```

> **Status:** capture, contextual review, immutable Markdown exports, and host
> installation diagnostics are implemented. Source-app adoption remains roadmap work.

Open [the standalone Phase 7 report](page-feedback.html) for an easy-to-scan,
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
  config.current_actor = lambda do |controller|
    controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
  end
  config.capture_authorizer = PageFeedback::Configuration::DEFAULT_AUTHORIZER
  config.review_authorizer = PageFeedback::Configuration::DEFAULT_AUTHORIZER
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

The doctor checks the mount, host files, callbacks, migrations, tables, assets,
formatter, and packaged docs. Use `PAGE_FEEDBACK_FORMAT=json` for stable machine
output; warnings such as intentionally open authorization do not make it fail.

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
