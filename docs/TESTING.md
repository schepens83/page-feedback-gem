# Testing

## Commands

```bash
bundle exec rspec path/to/spec.rb        # focused red-green cycle
bundle exec rake spec                    # complete Ruby suite
npm test                                 # dependency-free browser module suite
bundle exec rubocop                      # static style checks
bundle exec rbs -I sig validate          # public Ruby signatures
bundle exec yard doc --fail-on-warning --no-output --exclude '^sig/' # inline API docs
gem build page_feedback.gemspec          # package contents and metadata
```

The CI compatibility graphs are reproducible locally through their committed
matrix Gemfiles:

```bash
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle exec rake spec
BUNDLE_GEMFILE=gemfiles/rails_8_1.gemfile bundle exec rake spec
```

The dummy Rails application supplies real routing, database, controller, asset,
and host-integration boundaries. Tests should not replace those boundaries with
mocks when observable behavior is practical.

Browser modules use Node's built-in test runner and require no npm packages.
`bundle exec rake javascript` is a convenience alias for `npm test`.
Clipboard coverage exercises the modern API, the selection-based fallback, and
the visible failure state without requiring a browser dependency.

Capybara's Rack Test driver covers server-rendered system paths without browser
screenshots. Phase 5 exercises the real dummy-host widget through anonymous
capture, page-queue navigation, refinement, and approval.

FactoryBot definitions live in `spec/factories` and are registered explicitly
because `Rails.root` points at `spec/dummy`. The committed dummy schema is
generated from both dummy-host and engine migration paths.

## Layers

- Model specs cover validation, actors, transitions, fingerprints, export state,
  transactions, immutability, ordering, and membership.
- Request specs cover authorization, formats, normalization, limits, CSRF,
  queues, decisions, and exports.
- JavaScript unit tests cover selectors, limits, shortcuts, context buffers,
  replay resilience, and clipboard fallbacks.
- System specs cover capture through review, export, stale detection, and
  restoration using the dummy host.
- Generator and diagnostics specs cover idempotence, skip options, broken host
  fixtures, human output, and stable JSON.

Phase 7 additionally executes the packaged help, docs, and version entry points,
checks safe installer reversal and forced-overwrite visibility, verifies every
declared broken-host fixture, and asserts that Rails exposes both doctor and
migration-install tasks.

## Compatibility

The minimum contract is Ruby 3.2 and Rails 8.0; the current track is Ruby 3.4
with Rails 8.1. CI must exercise both ends, SQLite, and the selected Importmap,
Turbo, Stimulus, and Propshaft integrations. Diagnostic Engine's PostgreSQL suite
is an adoption gate, not a substitute for the engine's isolated tests.

## Phase discipline

Every phase in `IMPLEMENTATION_PLAN.md` defines its own gate. Do not proceed past
a failing automated gate. Browser screenshots and proof-of-work tools are used
only when the user explicitly requests them; ordinary tests are the default.
