# frozen_string_literal: true

require_relative "../page_feedback"

module PageFeedback
  # Implements the packaged PageFeedback command-line interface.
  class Command
    HELP = <<~HELP
      Usage: page_feedback COMMAND [options]

      Inspect or diagnose a PageFeedback Rails engine installation.

      Commands:
        doctor [--json]  Boot the current Rails app and check its installation
        docs             Print installed documentation paths
        version          Print the PageFeedback version
        help             Show this complete help

      Examples:
        bundle exec page_feedback doctor
        bundle exec page_feedback doctor --json
        PAGE_FEEDBACK_FORMAT=json bundle exec page_feedback doctor

      The install generator creates the initializer, engine mount, layout helpers,
      and Stimulus proxy controllers. Capture and review authorization are open by
      default; review the generated initializer before production use.
    HELP

    class << self
      # Run the CLI and return its process status.
      # @param arguments [Array<String>] command arguments
      # @return [Integer]
      def run(arguments, **)
        new(arguments, **).run
      end
    end

    def initialize(arguments, **options)
      @arguments = arguments.dup
      @out = options.fetch(:out, $stdout)
      @err = options.fetch(:err, $stderr)
      @env = options.fetch(:env, ENV)
      @cwd = options.fetch(:cwd, Dir.pwd)
      @environment_loader = options[:environment_loader] || method(:load_rails_environment)
      @diagnostics_factory = options[:diagnostics_factory] || -> { Diagnostics.new }
    end

    # Dispatch the requested command.
    # @return [Integer] shell status
    def run
      case @arguments.shift || "help"
      when "doctor" then doctor
      when "docs" then docs
      when "version", "--version", "-v" then version
      when "help", "--help", "-h" then help
      else unknown_command
      end
    rescue StandardError => e
      @err.puts "PageFeedback: #{e.message}"
      1
    end

    private

    def doctor
      @environment_loader.call
      report = @diagnostics_factory.call.call
      @out.puts(json? ? report.to_json : report.to_text)
      report.ok? ? 0 : 1
    end

    def docs
      @out.puts "PageFeedback documentation:"
      @out.puts "  #{PageFeedback::Engine.root.join('README.md')}"
      @out.puts "  #{PageFeedback::Engine.root.join('docs')}"
      0
    end

    def version
      @out.puts PageFeedback::VERSION
      0
    end

    def help
      @out.puts HELP
      0
    end

    def unknown_command
      @err.puts "Unknown command. Run `page_feedback help` for usage."
      1
    end

    def json?
      @arguments.delete("--json") || @env["PAGE_FEEDBACK_FORMAT"] == "json"
    end

    def load_rails_environment
      path = File.expand_path("config/environment.rb", @cwd)
      raise "Rails application not found at #{@cwd}" unless File.file?(path)

      require path
    end
  end
end
