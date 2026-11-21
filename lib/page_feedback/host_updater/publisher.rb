# frozen_string_literal: true

module PageFeedback
  class HostUpdater
    # Commits a host's Gemfile and lockfile and pushes the current branch.
    class Publisher
      # @param root [String] the host repository directory
      # @param message [String] the commit message
      # @param runner [#call] command runner, see {HostUpdater#initialize}
      def initialize(root, message, runner)
        @root = root
        @message = message
        @runner = runner
      end

      # @return [Array(Symbol, String), nil] failure status and detail, or nil
      #   when the change was committed and pushed
      def publish
        step(%w[add Gemfile Gemfile.lock], "git add failed") ||
          step(["commit", "-m", @message], "git commit failed") ||
          step(["push", "origin", "HEAD:refs/heads/#{branch}"], "commit done; push failed")
      end

      private

      def step(args, detail)
        _out, err, status = git(*args)
        [:failed, "#{detail}: #{err.strip.lines.last}"] unless status.success?
      end

      def branch
        git("branch", "--show-current").first.strip
      end

      def git(*args)
        @runner.call(["git", "-C", @root, *args], chdir: @root)
      end
    end
  end
end
