# frozen_string_literal: true

require "open3"
require_relative "host_updater/gemfile"
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
    #   defaults to {#run_command}
    def initialize(version:, roots: nil, dry_run: false, runner: nil)
      @version = "v#{version.to_s.delete_prefix('v')}"
      @roots = Array(roots || configured_roots)
      @dry_run = dry_run
      @runner = runner || method(:run_command)
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
      return result(root, :dirty, "working tree has uncommitted changes") unless worktree_clean?(root)
      return result(root, :would_update, "#{tag[:value]} -> #{@version}") if @dry_run

      apply(root, gemfile, lines, tag)
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
      failure = refresh_dependencies(root, gemfile, original)
      return failure if failure

      failure = commit_and_push(root)
      return failure if failure

      result(root, :updated, "#{tag[:value]} -> #{@version}")
    end

    # @return [String] the new `tag:` value, preserving the original style
    def tag_replacement(tag)
      "#{tag[:prefix]}#{tag[:colon]}#{tag[:quote]}#{@version}#{tag[:quote]}"
    end

    # @return [Result, nil] a failure report, or nil when dependencies refresh
    def refresh_dependencies(root, gemfile, original)
      _out, err, status = @runner.call(%w[bundle update page_feedback], chdir: root)
      return nil if status.success?

      File.write(gemfile, original)
      result(root, :failed, "bundle update failed: #{err.strip.lines.last}")
    end

    # @return [Result, nil] a failure report, or nil when the change was pushed
    def commit_and_push(root)
      failure = run_git(root, ["git", "-C", root, "add", "Gemfile", "Gemfile.lock"], "git add failed")
      return failure if failure

      commit = ["git", "-C", root, "commit", "-m", "Bump page_feedback to #{@version}"]
      failure = run_git(root, commit, "git commit failed")
      return failure if failure

      run_git(root, push_command(root), "commit done; push failed")
    end

    # @return [Result, nil] a failure report, or nil when the command succeeded
    def run_git(root, command, failure_detail)
      _out, err, status = @runner.call(command, chdir: root)
      return nil if status.success?

      result(root, :failed, "#{failure_detail}: #{err.strip.lines.last}")
    end

    def push_command(root)
      branch = current_branch(root)
      ["git", "-C", root, "push", "origin", "HEAD:refs/heads/#{branch}"]
    end

    def current_branch(root)
      out, = @runner.call(["git", "-C", root, "branch", "--show-current"], chdir: root)
      out.strip
    end

    def worktree_clean?(root)
      out, _err, status = @runner.call(["git", "-C", root, "status", "--porcelain"], chdir: root)
      status.success? && out.strip.empty?
    end

    def result(repo, status, detail)
      Result.new(repo: repo, status: status, detail: detail)
    end

    # @return [Array(String, String, Process::Status)]
    def run_command(command, chdir:)
      Open3.capture3(*command, chdir: chdir)
    end
  end
end
