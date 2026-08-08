# frozen_string_literal: true

module PageFeedback
  class Diagnostics
    # Checks runtime versions, dependencies, configuration, and packaged assets.
    module RuntimeChecks
      # Supported runtime gem versions keyed by package name.
      DEPENDENCIES = {
        "rails" => Gem::Requirement.new(">= 8.0", "< 9.0"),
        "importmap-rails" => Gem::Requirement.new(">= 2.0"),
        "turbo-rails" => Gem::Requirement.new(">= 2.0"),
        "stimulus-rails" => Gem::Requirement.new(">= 1.3"),
        "propshaft" => Gem::Requirement.new(">= 1.0")
      }.freeze

      private

      def gem_version_check
        pass("gem_version", "Gem version", PageFeedback::VERSION)
      end

      def rails_version_check
        requirement = DEPENDENCIES.fetch("rails")
        if requirement.satisfied_by?(Gem::Version.new(rails_version))
          return pass("rails_version", "Rails version", rails_version)
        end

        fail_check("rails_version", "Rails version unsupported", rails_version)
      end

      def dependencies_check
        failures = DEPENDENCIES.except("rails").filter_map do |name, requirement|
          spec = @gem_registry[name]
          name unless spec && requirement.satisfied_by?(spec.version)
        end
        return pass("dependencies", "Runtime dependencies loaded") if failures.empty?

        fail_check("dependencies", "Runtime dependencies missing or unsupported", failures.join(", "))
      end

      def callbacks_check
        names = %i[current_actor capture_authorizer review_authorizer actor_label source_locator export_formatter]
        invalid = names.reject { |name| configuration.public_send(name).respond_to?(:call) }
        return pass("configuration_callbacks", "Configuration callbacks callable") if invalid.empty?

        fail_check("configuration_callbacks", "Configuration callbacks invalid", invalid.join(", "))
      end

      def open_authorization_check
        open = %i[capture_authorizer review_authorizer].select do |name|
          configuration.public_send(name).equal?(Configuration::DEFAULT_AUTHORIZER)
        end
        return pass("open_authorization", "Authorization callbacks customized") if open.empty?

        warn("open_authorization", "Authorization is open", open.join(", "))
      end

      def default_category_check
        valid = configuration.categories.key?(configuration.default_category)
        return pass("default_category", "Default category configured", configuration.default_category) if valid

        fail_check("default_category", "Default category missing", configuration.default_category)
      end

      def formatter_check
        body = configuration.export_formatter.call(comments: [], generated_at: Time.current)
        return pass("export_formatter", "Markdown formatter responds to .call") if body.is_a?(String)

        fail_check("export_formatter", "Export formatter must return a String", body.class.name)
      rescue StandardError => e
        fail_check("export_formatter", "Export formatter failed", "#{e.class}: #{e.message}")
      end

      def assets_check
        load_path = application.assets.load_path
        assets = %w[page_feedback/page_feedback.css page_feedback/controllers/capture_controller.js]
        return pass("assets", "Engine assets resolvable") if assets.all? { |asset| load_path.find(asset) }

        fail_check("assets", "Engine assets are not resolvable")
      rescue StandardError => e
        fail_check("assets", "Engine assets are not resolvable", e.class.name)
      end
    end
  end
end
