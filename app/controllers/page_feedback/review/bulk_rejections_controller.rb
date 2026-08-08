# frozen_string_literal: true

module PageFeedback
  module Review
    # Rejects selected pending or approved feedback as one REST collection resource.
    class BulkRejectionsController < BaseController
      # Reject every eligible selected comment.
      #
      # @return [void]
      def create
        Comment.transaction do
          Comment.where(id: selected_comment_ids, status: %w[pending approved]).find_each do |comment|
            comment.reject!(reviewer: page_feedback_current_actor)
          end
        end
        redirect_to queue_redirect_path, status: :see_other
      end
    end
  end
end
