# frozen_string_literal: true

require "open3"

module PageFeedback
  class HostUpdater
    # Runs host commands with the host's own Ruby instead of the caller's.
    #
    # Bundler and Ruby commands are wrapped in `mise x -C <host> --` when mise
    # is on PATH, so the host's `.ruby-version` decides the Ruby. Inherited
    # Ruby and Bundler environment variables are unset so a caller running
    # under another Ruby or `bundle exec` cannot leak into the host.
    class CommandRunner
      # Variables always unset, whether or not the caller has them.
      SCRUBBED = %w[RUBYOPT RUBYLIB GEM_HOME GEM_PATH BUNDLE_GEMFILE BUNDLE_BIN_PATH
                    BUNDLER_VERSION BUNDLER_SETUP].freeze
      PASSTHROUGH = %w[git].freeze

      # @param mise [Boolean, nil] force mise wrapping on or off; detected from
      #   PATH when nil
      # @param inherited [Hash{String=>String}] the caller's environment
      def initialize(mise: nil, inherited: ENV.to_h)
        @mise = mise.nil? ? mise_on_path? : mise
        @inherited = inherited
      end

      # @param command [Array<String>] the command and arguments
      # @param chdir [String] the host directory
      # @return [Array(String, String, Process::Status)] stdout, stderr, status
      def call(command, chdir:)
        Open3.capture3(environment, *wrap(command, chdir), chdir: chdir)
      end

      # @return [Array<String>] the command, wrapped for mise when applicable
      def wrap(command, chdir)
        return command if !@mise || PASSTHROUGH.include?(command.first)

        ["mise", "x", "-C", chdir, "--", *command]
      end

      # @return [Hash{String=>nil}] variables to unset in the child process
      def environment
        leaked = @inherited.keys.grep(/\A(BUNDLE|BUNDLER)_/)
        (SCRUBBED + leaked).uniq.zip([]).to_h
      end

      private

      def mise_on_path?
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          File.executable?(File.join(dir, "mise"))
        end
      end
    end
  end
end
