# frozen_string_literal: true

module PageFeedback
  module Review
    # Creates approval decisions for the entire pending review queue.
    class QueueApprovalsController < BaseController
      # Approve every pending comment, limited by the active category when set.
      #
      # @return [void]
      def create
        reviewer = page_feedback_current_actor
        comments = Comment.pending
        comments = comments.by_category(review_category) if review_category

        Comment.transaction do
          comments.find_each { |comment| comment.approve!(reviewer:) }
        end

        redirect_to review_pages_path(filter: "pending", category: review_category), status: :see_other
      end
    end
  end
end
