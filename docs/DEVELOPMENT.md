# Development

## Setup

Use a Ruby version supported by the gem, install dependencies, and run the
baseline checks:

```bash
bundle install
bundle exec rake spec
bundle exec rubocop
gem build page_feedback.gemspec
```

The root `Rakefile` makes specs the default task. The isolated Rails application
in `spec/dummy` is the integration host; use its `bin/rails` entry point for
routes, migrations, runner commands, and manual browser development.

## Working method

Work through `IMPLEMENTATION_PLAN.md` in order. Start each behavior with a focused
failing spec, make the smallest contract-complete change that passes, then
refactor with the focused test still green. Run the full phase gate before
crossing a phase boundary. Commit and push each coherent slice.

## Source parity

The original behavior lives in `/home/sander/Projects/diagnostic-engine` at
baseline `058e92c75b79d4592b622f6a16ca1f62d9b9c493`. Inspect that revision during
browser capture, review, and adoption work. Preserve behavior while replacing
source-app class and controller structure with the engine contracts.

## Documentation

Update documentation in the same change as its behavior. Root `AGENTS.md` maps
change types to canonical docs. Keep command help concise; do not duplicate the
architecture or implementation plan into generated files.

## Releases

The project is unreleased. Licensing and publication metadata remain provisional.
Do not push a gem or tag until Phase 9 gates pass and the owner selects a license.
