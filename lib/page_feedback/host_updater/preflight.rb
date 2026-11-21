# frozen_string_literal: true

module PageFeedback
  class HostUpdater
    # Read-only checks on a host repository before anything is edited: it must
    # be clean, not trail its upstream and its active Ruby must match `.ruby-version`.
    class Preflight
      # @param root [String] the host repository directory
      # @param runner [#call] command runner, see {HostUpdater#initialize}
      def initialize(root, runner)
        @root = root
        @runner = runner
      end

      # @return [Array(Symbol, String), nil] status and detail of the first
      #   problem found, or nil when the host is safe to edit
      def problem
        dirty || behind || ruby_mismatch
      end

      private

      def dirty
        out, _err, status = git("status", "--porcelain")
        [:dirty, "working tree has uncommitted changes"] unless status.success? && out.strip.empty?
      end

      def behind
        _out, err, status = git("fetch")
        return [:failed, "git fetch failed: #{err.strip.lines.last}"] unless status.success?

        out, _err, counted = git("rev-list", "--count", "HEAD..@{u}")
        count = counted.success? ? out.to_i : 0
        [:behind, "behind origin by #{count} #{count == 1 ? 'commit' : 'commits'}; pull first"] if count.positive?
      end

      def ruby_mismatch
        wanted = wanted_ruby
        return nil unless wanted&.match?(/\A\d/)

        out, = @runner.call(["ruby", "-e", "print RUBY_VERSION"], chdir: @root)
        active = out.strip
        return nil if active == wanted || active.start_with?("#{wanted}.")

        [:failed, "ruby #{active} active but .ruby-version wants #{wanted}"]
      end

      def wanted_ruby
        file = File.join(@root, ".ruby-version")
        File.read(file).strip.delete_prefix("ruby-") if File.file?(file)
      end

      def git(*args)
        @runner.call(["git", "-C", @root, *args], chdir: @root)
      end
    end
  end
end
