# frozen_string_literal: true

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.active_support.deprecation = :stderr
  config.action_dispatch.show_exceptions = :rescuable
  config.secret_key_base = "page-feedback-dummy-test-secret-key-base"
end
