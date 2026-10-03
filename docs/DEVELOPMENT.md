# Development

## Setup

Use a Ruby version supported by the gem, install dependencies, and run the
baseline checks:

```bash
bundle install
bundle exec rake spec
npm test
bundle exec rubocop
bundle exec rbs -I sig validate
bundle exec yard doc --fail-on-warning --no-output --exclude '^sig/'
gem build page_feedback.gemspec
```

The root `Rakefile` makes specs the default task. The isolated Rails application
in `spec/dummy` is the integration host; use its `bin/rails` entry point for
routes, migrations, runner commands, and manual browser development.

Run dummy database tasks from the dummy root so Rails finds its host Rakefile:

```bash
cd spec/dummy
bin/rails db:prepare
```

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

The gem is not published to RubyGems and uses the MIT License. Host apps
install it from GitHub pinned to a release tag:

```ruby
gem "page_feedback", github: "schepens83/page-feedback-gem", tag: "v0.1.1"
```

To cut a release:

1. Bump `PageFeedback::VERSION` and its spec (patch for fixes, minor for
   features).
2. Move the `[Unreleased]` CHANGELOG entries under a new
   `## [x.y.z] - YYYY-MM-DD` heading.
3. Run `bundle install` and, for each Rails gemfile,
   `BUNDLE_GEMFILE=gemfiles/<name>.gemfile bundle install` to refresh lockfiles.
4. Run the full gate, commit, then `git tag vX.Y.Z && git push origin main vX.Y.Z`.
5. Hosts adopt the new tag. Do not run `rake release` here: `bundler/gem_tasks`
   exposes it, and it tries to push the built gem to RubyGems after tagging —
   follow the manual steps above instead. Hosts pick the version up through a
   Dependabot pull request (see `docs/INSTALLATION.md#adopting-a-new-gem-version`)
   or by changing the Gemfile `tag:` and running `bundle update page_feedback`.
   Kamal never updates bundles during deploy; it ships the lockfile that is
   committed in the host repo.
