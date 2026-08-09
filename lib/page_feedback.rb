# frozen_string_literal: true

require "page_feedback/version"
require "page_feedback/actor_label"
require "page_feedback/exporters/markdown"
require "page_feedback/configuration"
require "page_feedback/diagnostics"
require "page_feedback/engine"

# Capture, review, and export contextual feedback inside a host Rails app.
module PageFeedback
  class << self
    # Current engine configuration.
    #
    # @return [PageFeedback::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Update the current configuration.
    #
    # @yieldparam configuration [PageFeedback::Configuration]
    # @return [PageFeedback::Configuration]
    def configure
      yield(configuration)
      configuration
    end

    # Replace the current configuration with defaults.
    #
    # This is public primarily so hosts and tests can isolate configuration.
    # @return [PageFeedback::Configuration]
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
