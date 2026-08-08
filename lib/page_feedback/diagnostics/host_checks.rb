# frozen_string_literal: true

module PageFeedback
  class Diagnostics
    # Checks host files, routing, migrations, tables, and documentation.
    module HostChecks
      TABLES = %w[page_feedback_comments page_feedback_exports page_feedback_export_items].freeze

      private

      def engine_mount_check
        route = application.routes.routes.find do |candidate|
          candidate.app.respond_to?(:app) && candidate.app.app == PageFeedback::Engine
        end
        return fail_check("engine_mount", "Engine mount missing") unless route

        pass("engine_mount", "Engine mounted at", route.path.spec.to_s.sub("(.:format)", ""))
      end

      def initializer_check
        path = root.join("config/initializers/page_feedback.rb")
        return pass("initializer", "Initializer present", relative(path)) if path.file?

        fail_check("initializer", "Initializer missing", relative(path))
      end

      def migrations_installed_check
        expected = migration_names(@engine_root.join("db/migrate"))
        missing = expected - migration_names(root.join("db/migrate"))
        return pass("migrations_installed", "Engine migrations installed") if missing.empty?

        fail_check("migrations_installed", "Engine migrations missing", missing.join(", "))
      end

      def migrations_pending_check
        return pass("migrations_pending", "No pending migrations") unless migration_context.needs_migration?

        fail_check("migrations_pending", "Database migrations pending")
      rescue StandardError => e
        fail_check("migrations_pending", "Migration status unavailable", e.class.name)
      end

      def tables_check
        missing = TABLES.reject { |table| connection.data_source_exists?(table) }
        return pass("tables", "Database tables present") if missing.empty?

        fail_check("tables", "Database tables missing", missing.join(", "))
      rescue StandardError => e
        fail_check("tables", "Database tables unavailable", e.class.name)
      end

      def layout_helpers_check
        contents = layout_contents
        missing = %w[page_feedback_head page_feedback_widget].reject { |helper| contents.include?(helper) }
        return pass("layout_helpers", "Layout helpers installed") if missing.empty?

        fail_check("layout_helpers", "Layout helpers missing", missing.join(", "))
      end

      def stimulus_proxy_check
        missing = %w[capture copy].reject do |name|
          root.join("app/javascript/controllers/page_feedback_#{name}_controller.js").file?
        end
        return pass("stimulus_proxy", "Stimulus proxy controllers installed") if missing.empty?

        fail_check("stimulus_proxy", "Stimulus proxy controllers missing", missing.join(", "))
      end

      def documentation_check
        required = [@engine_root.join("README.md"), @engine_root.join("docs/INSTALLATION.md")]
        return pass("documentation", "Documentation available", docs_path) if required.all?(&:file?)

        fail_check("documentation", "Documentation missing", docs_path)
      end

      def migration_names(directory)
        directory.glob("*.rb").map { |path| path.basename.to_s.sub(/\A\d+_/, "") }
      end

      def layout_contents
        root.glob("app/views/layouts/application.html.*").filter_map do |path|
          path.read if path.file?
        end.join("\n")
      end

      def relative(path)
        path.relative_path_from(root).to_s
      end
    end
  end
end
