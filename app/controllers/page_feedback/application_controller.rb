# frozen_string_literal: true

module PageFeedback
  # Host-aware base controller for all engine requests.
  class ApplicationController < ::ApplicationController
    private

    def page_feedback_current_actor
      PageFeedback.configuration.current_actor.call(self)
    end

    def ensure_capture_authorized
      head :forbidden unless PageFeedback.configuration.capture_authorizer.call(self)
    end

    def ensure_review_authorized
      head :forbidden unless PageFeedback.configuration.review_authorizer.call(self)
    end
  end
end
