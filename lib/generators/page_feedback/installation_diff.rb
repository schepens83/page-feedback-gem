# frozen_string_literal: true

module PageFeedback
  module Generators
    # Preserves customized generator targets unless force is explicit and visible.
    module InstallationDiff
      private

      def install_template(source, destination)
        show_forced_difference(source, destination)
        template source, destination
      end

      def show_forced_difference(source, destination)
        target = destination_path(destination)
        return unless options[:force] && File.exist?(target)

        replacement = File.read(File.join(self.class.source_root, source))
        current = File.read(target)
        return if current == replacement

        say "--- #{destination} (current)\n+++ #{destination} (generated)", :yellow
        current.each_line { |line| say "- #{line}", :red, false }
        replacement.each_line { |line| say "+ #{line}", :green, false }
      end
    end
  end
end
