# frozen_string_literal: true

require_relative "host_updater/command_runner"
require_relative "host_updater/gemfile"
require_relative "host_updater/lockfile_diff"
require_relative "host_updater/preflight"
require_relative "host_updater/publisher"
require_relative "host_updater/result"

module PageFeedback
  # Adopts a released tag in every local host repository that installs
  # page_feedback from GitHub. Used by maintainers right after a release:
  # it rewrites each host's `tag:` option, refreshes the lockfile, and commits
  # and pushes the change, so consuming applications pick up the new version
  # without any per-host Gemfile edits.
  #
  # Repositories that pin by `ref:` or `branch:` are skipped with a report row;
  # the updater never guesses about those decisions.
  class HostUpdater
    SKIP_DETAILS = {
      no_declaration: "page_feedback not declared",
      ref_pin: "pinned by commit ref; update manually",
      branch_pin: "pinned by branch; update manually",
      no_tag: "declared without a tag"
    }.freeze

    # @return [Array<String>] local host directories, globbed from
    #   `~/Projects/*`, excluding this gem's own repository
    def self.default_roots
      gem_root = File.expand_path("../..", __dir__)
      Dir[File.join(Dir.home, "Projects", "*")].reject do |root|
        File.expand_path(root) == gem_root
      end
    end

    # @param version [String] the released version, e.g. "0.2.0"
    # @param roots [Array<String>, nil] host directories; defaults to
    #   {default_roots} unless `PAGE_FEEDBACK_HOSTS` (space-separated) is set
    # @param dry_run [Boolean] report intended changes without writing files or
    #   running bundle/git commands
    # @param runner [#call] command runner returning `[stdout, stderr, status]`;
    #   defaults to {CommandRunner}
    def initialize(version:, roots: nil, dry_run: false, runner: nil)
      @version = "v#{version.to_s.delete_prefix('v')}"
      @roots = Array(roots || configured_roots)
      @dry_run = dry_run
      @runner = runner || CommandRunner.new
    end

    # Update every configured host repository.
    # @return [Array<Result>] one result per repository, in root order
    def call
      @roots.map { |root| update(root) }
    end

    private

    def configured_roots
      from_env = ENV["PAGE_FEEDBACK_HOSTS"].to_s.split(/\s+/)
      from_env.empty? ? self.class.default_roots : from_env
    end

    def update(root)
      gemfile = File.join(root, "Gemfile")
      return result(root, :no_gemfile, "no Gemfile") unless File.file?(gemfile)

      analysis = analyze(root, gemfile)
      return analysis if analysis.is_a?(Result)

      lines, tag = analysis
      return result(root, :up_to_date, "already on #{@version}") if tag[:value] == @version

      blocked = preflight(root)
      return blocked if blocked
      return result(root, :would_update, "#{tag[:value]} -> #{@version}") if @dry_run

      apply(root, gemfile, lines, tag)
    end

    # Read-only checks (clean worktree, fresh remote, right Ruby) that run even
    # in a dry run.
    # @return [Result, nil] a skip or failure report, or nil when safe to edit
    def preflight(root)
      problem = Preflight.new(root, @runner).problem
      result(root, *problem) if problem
    end

    # Locate the page_feedback declaration and its tag option.
    # @param root [String] the host repository directory
    # @param gemfile [String] the host Gemfile path
    # @return [Array(Array<String>, Hash), Result] statement lines plus the
    #   matched tag, or a {Result} when the host cannot be updated
    def analyze(root, gemfile)
      outcome = Gemfile.analyze(gemfile)
      return outcome if outcome.is_a?(Array)

      result(root, outcome, SKIP_DETAILS.fetch(outcome))
    end

    def apply(root, gemfile, lines, tag)
      original = lines.join
      lines[tag[:line_index]] = lines[tag[:line_index]].sub(Gemfile::TAG_OPTION, tag_replacement(tag))
      File.write(gemfile, lines.join)
      failure = refresh_dependencies(root) || guard_lockfile(root) || install_bundle(root)
      return restore(root, gemfile, original, failure) if failure

      failure = commit_and_push(root)
      return failure if failure

      result(root, :updated, "#{tag[:value]} -> #{@version}")
    end

    # Put the host's worktree back exactly as it was before the edit.
    # @return [Result] the failure, unchanged
    def restore(root, gemfile, original, failure)
      File.write(gemfile, original)
      @runner.call(["git", "-C", root, "checkout", "--", "Gemfile", "Gemfile.lock"], chdir: root)
      failure
    end

    # @return [String] the new `tag:` value, preserving the original style
    def tag_replacement(tag)
      "#{tag[:prefix]}#{tag[:colon]}#{tag[:quote]}#{@version}#{tag[:quote]}"
    end

    # @return [Result, nil] a failure report, or nil when the lock succeeded
    def refresh_dependencies(root)
      run_step(root, %w[bundle lock --update page_feedback --conservative], "bundle lock failed")
    end

    # @return [Result, nil] a failure when the lock touched unrelated gems
    def guard_lockfile(root)
      diff, = @runner.call(["git", "-C", root, "diff", "-U0", "--", "Gemfile.lock"], chdir: root)
      unexpected = LockfileDiff.unexpected_lines(diff)
      return nil if unexpected.empty?

      result(root, :failed, "Gemfile.lock changed unexpectedly: #{unexpected.first(3).join(', ')}")
    end

    # @return [Result, nil] a failure report, or nil when gems are installed
    def install_bundle(root)
      run_step(root, %w[bundle install], "bundle install failed")
    end

    def run_step(root, command, failure_detail)
      _out, err, status = @runner.call(command, chdir: root)
      return nil if status.success?

      result(root, :failed, "#{failure_detail}: #{err.strip.lines.last}")
    end

    # @return [Result, nil] a failure report, or nil when the change was pushed
    def commit_and_push(root)
      problem = Publisher.new(root, "Bump page_feedback to #{@version}", @runner).publish
      result(root, *problem) if problem
    end

    def result(repo, status, detail)
      Result.new(repo: repo, status: status, detail: detail)
    end
  end
end
