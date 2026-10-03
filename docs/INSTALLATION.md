# Installation

## New host application

Add `page_feedback` to the Gemfile, install dependencies, run the installer,
copy migrations, migrate, and run diagnostics:

```bash
bundle install
bin/rails generate page_feedback:install
bin/rails page_feedback:install:migrations
bin/rails db:migrate
bin/rails page_feedback:doctor
```

The default mount path is `/feedback`. The generator supports
`--mount-path=/custom`, `--skip-route`, `--skip-layout`, `--skip-stimulus`, and
`--force`. It is idempotent and does not overwrite customized files without an
explicit force option and visible diff.

The generator creates one Stimulus proxy, for the capture controller. The review
UI loads its own controllers, so it needs no host proxy. Run
`bin/rails destroy page_feedback:install` to remove exact generated files and
insertions; copied migrations, tables, and data are intentionally preserved.
Hosts installed before this change may still have an unused
`app/javascript/controllers/page_feedback_copy_controller.js`, which is safe to
delete.

## Authorization

The generated initializer allows anonymous capture and open review so the engine
works in applications without authentication. This is intentional and visible
in initializer comments and doctor warnings. Production hosts normally replace
the callbacks with their existing actor and role methods; see
[Public API](PUBLIC_API.md).

## Manual host seams

The engine mount, `page_feedback_head`, `page_feedback_widget`, and generated
Stimulus proxy are the only layout/runtime seams. If the host lacks the standard
Stimulus controller loader, register the engine controller manually using the
instructions printed by the generator rather than starting a second Stimulus
application. These seams cover host-rendered pages only; the mounted review UI
loads its own JavaScript and needs nothing from the host layout.

## Diagnostics

`bin/rails page_feedback:doctor` checks compatible runtime dependencies, the
engine mount, initializer and callbacks, open authorization, installed and
pending migrations, tables, layout helpers, Stimulus proxies, resolvable assets,
the default category, formatter contract, and documentation. Warnings remain a
successful exit; missing required integration returns nonzero.

Use stable JSON for automation:

```bash
PAGE_FEEDBACK_FORMAT=json bin/rails page_feedback:doctor
bundle exec page_feedback doctor --json
```

## Upgrades

Update the gem, copy newly provided migrations, run database migrations, and
then run the doctor. Never edit a migration that has already shipped; add a new
migration. Review `CHANGELOG.md` for public behavior and configuration changes.

### Adopting a new gem version

For local host repositories the gem repo ships a one-command updater that does
the whole adoption after a release. It rewrites each host's `tag:` option,
refreshes the lockfile with `bundle update page_feedback`, and commits and
pushes the change:

```bash
# in the page-feedback-gem repo, right after pushing the release tag
bin/update_hosts
```

It discovers every project under `~/Projects` that declares the gem and
reports one row per repository. Repositories pinned by `ref:` or `branch:`
are skipped, and dirty worktrees are left alone — the updater never guesses
about those. Preview the result first with
`PAGE_FEEDBACK_DRY_RUN=1 bin/update_hosts`, or restrict the run with
`PAGE_FEEDBACK_HOSTS="/path/to/app /path/to/other"`.

The updater refreshes each host's bundle with the Ruby of the shell it runs
in. A host that pins a different Ruby (via `.ruby-version`) fails its row
with a version mismatch and its Gemfile is restored; update that host by
hand — bump the `tag:` and run `bundle update page_feedback` in the host's
own Ruby environment.

Hosts that are not on that machine (CI, other developers, other machines) can
be updated the usual way — bump the `tag:` in the Gemfile and refresh the
lockfile:

```ruby
gem "page_feedback", github: "schepens83/page-feedback-gem", tag: "v0.1.2"
```

```bash
bundle update page_feedback
```

Kamal does not update bundled gems. `kamal deploy` builds the application
image from the `Gemfile.lock` committed in the repo, so the pinned version is
exactly what ships. Merge the updater's commit — or run
`bundle update page_feedback` and commit — before deploying; the deploy itself
never fetches a newer version. Bundler git sources pin an exact ref, so a
version constraint such as `~> 0.2` never applies to tag-based installs; for
true `~>` semantics the gem would have to be installed from a gem server.

## Uninstall

The destroy form of the installer removes generated host files where it can do
so safely. It does not remove copied migrations, tables, or feedback data.
Remove those only through an explicit, reviewed host migration and backup plan.
