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
application.

## Upgrades

Update the gem, copy newly provided migrations, run database migrations, and
then run the doctor. Never edit a migration that has already shipped; add a new
migration. Review `CHANGELOG.md` for public behavior and configuration changes.

## Uninstall

The destroy form of the installer removes generated host files where it can do
so safely. It does not remove copied migrations, tables, or feedback data.
Remove those only through an explicit, reviewed host migration and backup plan.
