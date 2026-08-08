# frozen_string_literal: true

module PageFeedback
  module Review
    # Lists review pages. Queue behavior is implemented in Phase 5.
    class PagesController < BaseController
      # Authorize review before the Phase 5 queue endpoint runs.
      def index
        head :not_implemented
      end
    end
  end
end
