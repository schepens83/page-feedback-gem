# frozen_string_literal: true

module PageFeedback
  module Review
    # Applies host review authorization to every review resource.
    class BaseController < PageFeedback::ApplicationController
      REVIEW_ACTIONS = %i[index new create show edit update destroy].freeze

      before_action :ensure_review_authorized, only: REVIEW_ACTIONS
    end
  end
end
