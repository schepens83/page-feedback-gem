# frozen_string_literal: true

require "pathname"
require "rubygems"
require_relative "runtime_checks"
require_relative "host_checks"

module PageFeedback
  class Diagnostics
    # Executes the stable diagnostics check list against one host environment.
    class CheckRunner
      include RuntimeChecks
      include HostChecks

      attr_reader :application, :root, :configuration, :rails_version, :docs_path

      def initialize(application:, root:, configuration:, **options)
        @application = application
        @root = root
        @configuration = configuration
        @rails_version = options.fetch(:rails_version, Rails.version)
        @gem_registry = options.fetch(:gem_registry, Gem.loaded_specs)
        @engine_root = Pathname(options.fetch(:engine_root, PageFeedback::Engine.root))
        @docs_path = @engine_root.join("docs").to_s
        @connection = options[:connection]
        @migration_context = options[:migration_context]
      end

      # Run every check in stable public order.
      # @return [Array<PageFeedback::Diagnostics::Check>]
      def call
        [
          gem_version_check, rails_version_check, dependencies_check,
          engine_mount_check, initializer_check, callbacks_check,
          open_authorization_check, migrations_installed_check,
          migrations_pending_check, tables_check, layout_helpers_check,
          stimulus_proxy_check, assets_check, default_category_check,
          formatter_check, documentation_check
        ]
      end

      private

      def check(name, label, status, details = "")
        Check.new(name: name, label: label, status: status, details: details.to_s)
      end

      def pass(name, label, details = "")
        check(name, label, "pass", details)
      end

      def warn(name, label, details = "")
        check(name, label, "warn", details)
      end

      def fail_check(name, label, details = "")
        check(name, label, "fail", details)
      end

      def connection
        @connection ||= ActiveRecord::Base.connection
      end

      def migration_context
        @migration_context ||= ActiveRecord::Base.connection_pool.migration_context
      end
    end
  end
end
