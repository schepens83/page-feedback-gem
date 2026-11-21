# frozen_string_literal: true

module PageFeedback
  class HostUpdater
    # Judges a `git diff -U0 -- Gemfile.lock` after a conservative lock: only
    # the page_feedback source's revision and tag and its own version line may
    # change. Anything else means the lock touched unrelated gems.
    module LockfileDiff
      ALLOWED = [/\Arevision: \h+\z/, /\Atag: \S+\z/, /\Apage_feedback \([^)]+\)\z/].freeze

      # @param diff [String] unified diff with zero context lines
      # @return [Array<String>] changed lines outside the allowed set
      def self.unexpected_lines(diff)
        diff.lines(chomp: true).select { |line| changed?(line) && !allowed?(line) }
      end

      def self.changed?(line)
        line.match?(/\A[+-]/) && !line.start_with?("+++", "---")
      end

      def self.allowed?(line)
        content = line[1..].strip
        ALLOWED.any? { |pattern| content.match?(pattern) }
      end
    end
  end
end
