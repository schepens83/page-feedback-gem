# frozen_string_literal: true

require "rails"
require "rails/engine"
require "importmap-rails"
require "propshaft"
require "propshaft/railtie"
require "stimulus-rails"
require "turbo-rails"

module PageFeedback
  # Isolated Rails engine containing PageFeedback runtime components.
  class Engine < ::Rails::Engine
    isolate_namespace PageFeedback

    initializer "page_feedback.mime_types" do
      Mime::Type.register("text/markdown", :md) unless Mime::Type.lookup_by_extension(:md)
    end

    initializer "page_feedback.importmap", before: "importmap" do |app|
      importmap_path = root.join("config/importmap.rb")
      javascript_path = root.join("app/assets/javascripts")

      app.config.importmap.paths << importmap_path unless app.config.importmap.paths.include?(importmap_path)
      unless app.config.importmap.cache_sweepers.include?(javascript_path)
        app.config.importmap.cache_sweepers << javascript_path
      end
    end

    initializer "page_feedback.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper PageFeedback::ApplicationHelper
      end
    end
  end
end
