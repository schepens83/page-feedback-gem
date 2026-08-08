# frozen_string_literal: true

module PageFeedback
  module Review
    # Lists review pages. Queue behavior is implemented in Phase 5.
    class PagesController < BaseController
      def index
        head :not_implemented
      end
    end
  end
end
