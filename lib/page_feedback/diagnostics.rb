# frozen_string_literal: true

require "json"
require_relative "diagnostics/check_runner"

module PageFeedback
  # Runs host integration checks and renders stable human or JSON reports.
  class Diagnostics
    # One stable diagnostic observation.
    Check = Struct.new(:name, :label, :status, :details, keyword_init: true) do
      # JSON-compatible representation with stable public keys.
      # @return [Hash<String, String>]
      def to_h
        { "name" => name, "status" => status, "details" => details }
      end
    end

    # Immutable result of one diagnostics run.
    Report = Struct.new(:version, :rails_version, :checks, :review_path, :docs_path, keyword_init: true) do
      # Whether no required check failed. Warnings remain successful.
      # @return [Boolean]
      def ok?
        checks.none? { |check| check.status == "fail" }
      end

      # JSON-compatible representation with stable public keys.
      # @return [Hash<String, Object>]
      def to_h
        { "version" => version, "ok" => ok?, "checks" => checks.map(&:to_h) }
      end

      # Serialize the stable machine-readable report.
      # @return [String]
      def to_json(*)
        JSON.generate(to_h)
      end

      # Render the complete human-readable report.
      # @return [String]
      def to_text
        lines = ["PageFeedback #{version}", "Rails #{rails_version}", ""]
        lines.concat(checks.map { |check| human_check(check) })
        lines.push("", "Review: #{review_path}", "Docs:   #{docs_path}")
        lines.join("\n")
      end

      private

      def human_check(check)
        suffix = check.details.to_s.empty? ? "" : " #{check.details}"
        "#{check.status.upcase.ljust(5)} #{check.label}#{suffix}"
      end
    end

    # @param application [Rails::Application] host application
    # @param root [Pathname, String] host application root
    # @param configuration [PageFeedback::Configuration] active configuration
    def initialize(application: Rails.application, root: application.root,
                   configuration: PageFeedback.configuration, **options)
      @application = application
      @root = Pathname(root)
      @configuration = configuration
      @options = options
    end

    # Run all checks in their stable public order.
    # @return [PageFeedback::Diagnostics::Report]
    def call
      runner = CheckRunner.new(application: @application, root: @root,
                               configuration: @configuration, **@options)
      checks = runner.call
      Report.new(version: PageFeedback::VERSION, rails_version: runner.rails_version,
                 checks: checks, review_path: review_path(checks), docs_path: runner.docs_path)
    end

    private

    def review_path(checks)
      mount = checks.find { |check| check.name == "engine_mount" && check.status == "pass" }
      mount ? "http://localhost:3000#{mount.details}/review/pages" : "unavailable"
    end
  end
end
