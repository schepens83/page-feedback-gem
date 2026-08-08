# frozen_string_literal: true

require "rails/generators"
require_relative "installation_diff"

module PageFeedback
  # Rails generators shipped for host application integration.
  module Generators
    # Installs PageFeedback's explicit integration seams into a host Rails app.
    class InstallGenerator < Rails::Generators::Base
      include InstallationDiff

      source_root File.expand_path("templates", __dir__)

      desc <<~DESCRIPTION
        Install PageFeedback's initializer, engine mount, layout helpers, and
        Stimulus proxy controllers. Re-running is safe; --force prints the
        changed file before replacing it.

        Example:
          bin/rails generate page_feedback:install --mount-path=/feedback

        WARNING: capture and review authorization are open by default. Review
        the generated initializer before production use.
      DESCRIPTION
      class_option :mount_path, type: :string, default: "/feedback",
                                desc: "Local path where the engine is mounted"
      class_option :skip_route, type: :boolean, default: false,
                                desc: "Do not add the engine mount"
      class_option :skip_layout, type: :boolean, default: false,
                                 desc: "Do not add layout helpers"
      class_option :skip_stimulus, type: :boolean, default: false,
                                   desc: "Do not create Stimulus proxy controllers"

      def validate_mount_path
        return if mount_path.match?(%r{\A/(?:[^/?#]+(?:/[^/?#]+)*)?\z})

        raise Thor::Error, "--mount-path must be a local path without a query or fragment"
      end

      # Validate the configured mount and create the host initializer.
      def create_initializer
        install_template "page_feedback.rb", "config/initializers/page_feedback.rb"
      end

      # Add the engine mount unless a PageFeedback mount already exists.
      def mount_engine
        return if options[:skip_route]

        routes_path = destination_path("config/routes.rb")
        return say_status(:identical, "PageFeedback route", :blue) if behavior == :invoke && mounted?(routes_path)

        route %(mount PageFeedback::Engine => "#{mount_path}")
      end

      # Add capture helpers to the host's primary application layout.
      def integrate_layout
        return if options[:skip_layout]

        layout = application_layout
        return say_status(:skip, "application layout not found", :yellow) unless layout

        change_layout(layout, "page_feedback_head", "</head>")
        change_layout(layout, "page_feedback_widget", "</body>")
      end

      # Create host-loader proxies for each engine Stimulus controller.
      def create_stimulus_proxies
        return if options[:skip_stimulus]

        install_template "capture_controller.js", "app/javascript/controllers/page_feedback_capture_controller.js"
        install_template "copy_controller.js", "app/javascript/controllers/page_feedback_copy_controller.js"
      end

      # Print commands and URLs required to finish installation.
      def print_next_steps
        return if behavior == :revoke

        say <<~STEPS

          PageFeedback uses open capture and review authorization by default.
          Review config/initializers/page_feedback.rb before production use.

          Next:
            bin/rails page_feedback:install:migrations
            bin/rails db:migrate
            bin/rails page_feedback:doctor

          Review: http://localhost:3000#{mount_path}/review/pages
        STEPS
      end

      private

      def mount_path
        options[:mount_path].sub(%r{/+\z}, "").presence || "/"
      end

      def destination_path(relative_path)
        File.join(destination_root, relative_path)
      end

      def mounted?(routes_path)
        File.exist?(routes_path) && File.read(routes_path).include?("mount PageFeedback::Engine")
      end

      def application_layout
        %w[application.html.erb application.html.haml application.html.slim].filter_map do |name|
          path = destination_path(File.join("app/views/layouts", name))
          path if File.exist?(path)
        end.first
      end

      def change_layout(path, helper, closing_tag)
        relative_path = path.delete_prefix("#{destination_root}/")
        if behavior == :revoke
          remove_layout_helper(relative_path, helper)
        elsif File.read(path).include?(helper)
          say_status :identical, "#{relative_path} (#{helper})", :blue
        elsif File.extname(path) == ".erb"
          insert_into_file relative_path, layout_line(helper), before: closing_tag
        else
          say_status :skip, "#{relative_path}: add #{helper} manually", :yellow
        end
      end

      def remove_layout_helper(relative_path, helper)
        pattern = /^\s*<%= #{Regexp.escape(helper)} %>\r?\n/
        gsub_file relative_path, pattern, "", force: true
      end

      def layout_line(helper)
        "    <%= #{helper} %>\n"
      end
    end
  end
end
