# PageFeedback Agent Guide

PageFeedback is an isolated Rails 8 engine that captures element-level feedback,
supports in-context human review, and creates immutable, coding-agent-friendly
exports. The host Rails application owns authentication, authorization, users,
data, layout integration, and deployment.

## Read first

1. `docs/WHY.md`
2. `docs/IMPLEMENTATION_PLAN.md`
3. `docs/ARCHITECTURE.md`
4. `docs/PUBLIC_API.md`
5. The workflow, security, development, or testing document relevant to the task

## Repository map

- `app/`: isolated engine models, controllers, views, helpers, and browser assets
- `config/`: engine routes, importmap pins, and locale strings
- `db/migrate/`: migrations copied into host applications
- `lib/`: public API, engine integration, generators, diagnostics, and tasks
- `bin/`: maintainer-only scripts, not published in the gem
- `spec/`: unit and integration tests using `spec/dummy` as the host application
- `docs/`: canonical product, architecture, workflow, API, and maintenance docs
- `exe/`: small end-user command-line interface

## Invariants

- Keep engine Ruby constants, routes, tables, assets, CSS, and browser globals
  namespaced.
- Use Rails REST resources and the seven standard controller actions.
- Resolve actors from trusted host callbacks, never request parameters.
- Enforce capture and review authorization server-side and preserve CSRF.
- Keep review status independent from immutable export history.
- Replay only validated same-origin local paths and render captured HTML as text.
- Target Rails 8, Importmap, Turbo, Stimulus, and Propshaft only in v1.

## Commands

```bash
bundle install
bundle exec rake spec
bundle exec rubocop
bundle exec rbs -I sig validate
bundle exec yard doc --fail-on-warning --no-output --exclude '^sig/'
gem build page_feedback.gemspec
spec/dummy/bin/rails runner 'puts PageFeedback::VERSION'
spec/dummy/bin/rails routes
# Adopt a release in every local host repo (PAGE_FEEDBACK_DRY_RUN=1 previews)
bin/update_hosts
```

Use `bundle exec rspec path/to/spec.rb` for a focused red-green cycle. Run the
full three-command Phase 0 gate before declaring a phase complete. Do not use
browser proof tooling unless the user explicitly asks for it.

## Releases

Cut a release by bumping `PageFeedback::VERSION` and its spec, moving the
`[Unreleased]` CHANGELOG entries under a dated heading, running the full gate,
then `git tag vX.Y.Z && git push origin main vX.Y.Z`. Adopt the tag in every
local host with `bin/update_hosts` (dry-run first with
`PAGE_FEEDBACK_DRY_RUN=1`); it bumps each host's `tag:`, refreshes lockfiles,
and commits and pushes. Do not use `rake release` — `bundler/gem_tasks`
exposes it and it pushes the built gem to RubyGems. Kamal deploys the lockfile
committed in each host repo; it never runs bundle updates. Full runbook:
`docs/DEVELOPMENT.md`.

## Change discipline

- Write or change a failing test before implementation behavior.
- Keep migrations database-neutral and append-only after release.
- Treat documented public APIs as compatibility contracts; update tests and
  docs in the same commit when they change.
- Commit small, scoped changes and push each commit when a remote is available.

## Documentation matrix

- Configuration/API: `docs/PUBLIC_API.md`, initializer template, inline docs
- Install flow: `README.md`, `docs/INSTALLATION.md`, generator help, doctor
- Workflow/state: `docs/WORKFLOW.md`, `docs/ARCHITECTURE.md`, tests
- Durable decision: relevant ADR and `docs/ARCHITECTURE.md`
- Maintenance command: this file, `docs/DEVELOPMENT.md`, CLI help
- Security behavior: `docs/SECURITY.md`, initializer comments, tests
- Public behavior: `CHANGELOG.md` and the relevant canonical document

Licensing is provisional. Do not publish the gem or select a license without an
explicit project decision.
