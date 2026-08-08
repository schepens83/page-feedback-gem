# frozen_string_literal: true

require "rails"
require "rails/engine"

module PageFeedback
  # Isolated Rails engine containing PageFeedback runtime components.
  class Engine < ::Rails::Engine
    isolate_namespace PageFeedback
  end
end
