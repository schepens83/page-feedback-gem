# frozen_string_literal: true

module PageFeedback
  module Review
    # Decision resources that act on individual comments.
    module Comments
      # Creates approval decisions and removes them by returning to pending.
      class ApprovalsController < BaseController
        before_action :set_comment, only: %i[create destroy]

        # Save reviewer edits and approve the current revision atomically.
        #
        # @return [void]
        def create
          Comment.transaction do
            @comment.update!(reviewer_attributes)
            @comment.approve!(reviewer: page_feedback_current_actor)
          end
          redirect_to queue_redirect_path, status: :see_other
        end

        # Remove the approval decision.
        #
        # @return [void]
        def destroy
          @comment.return_to_pending!(reviewer: page_feedback_current_actor)
          redirect_to queue_redirect_path, status: :see_other
        end

        private

        def set_comment
          @comment = Comment.find(params.expect(:comment_id))
        end
      end
    end
  end
end
