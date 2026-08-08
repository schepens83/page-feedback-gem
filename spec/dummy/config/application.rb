# frozen_string_literal: true

require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)
require "page_feedback"

module Dummy
  # Minimal host application used for engine integration tests.
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = ENV["CI"].present?
    config.secret_key_base = "page-feedback-dummy-test-secret-key-base"
    config.paths["db/migrate"] << PageFeedback::Engine.root.join("db/migrate").to_s
  end
end
