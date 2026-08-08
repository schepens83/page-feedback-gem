# frozen_string_literal: true

PageFeedback.configure do |config|
  # PageFeedback works anonymously by default. Replace these open policies before
  # production use when feedback or review should require authentication.
  config.current_actor = lambda do |controller|
    controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
  end
  config.capture_authorizer = ->(_controller) { true }
  config.review_authorizer = ->(_controller) { true }

  # Authenticated examples:
  # config.capture_authorizer = ->(controller) { controller.send(:user_signed_in?) }
  # config.review_authorizer = ->(controller) { controller.send(:current_user)&.admin? }
end
