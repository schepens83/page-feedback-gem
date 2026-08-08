# frozen_string_literal: true

module PageFeedback
  module Review
    # Approves selected pending or rejected feedback as one REST collection resource.
    class BulkApprovalsController < BaseController
      # Approve every eligible selected comment.
      #
      # @return [void]
      def create
        Comment.transaction do
          Comment.where(id: selected_comment_ids, status: %w[pending rejected]).find_each do |comment|
            comment.approve!(reviewer: page_feedback_current_actor)
          end
        end
        redirect_to queue_redirect_path, status: :see_other
      end
    end
  end
end
