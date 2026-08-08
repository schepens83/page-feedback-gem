# frozen_string_literal: true

module PageFeedback
  # Host-authorized review resources.
  module Review
    # Applies host review authorization to every review resource.
    class BaseController < PageFeedback::ApplicationController
      # Every action allowed by the repository's REST-only controller contract.
      REVIEW_ACTIONS = %i[index new create show edit update destroy].freeze

      before_action :ensure_review_authorized, only: REVIEW_ACTIONS
    end
  end
end
