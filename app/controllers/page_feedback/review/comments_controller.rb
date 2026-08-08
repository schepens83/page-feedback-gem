# frozen_string_literal: true

module PageFeedback
  module Review
    # Shows and edits reviewer-authored fields without changing submitted evidence.
    class CommentsController < BaseController
      before_action :set_comment, only: %i[show update]

      # Render complete escaped feedback detail.
      #
      # @return [void]
      def show; end

      # Persist refined text and reviewer notes.
      #
      # @return [void]
      def update
        @comment.update!(reviewer_attributes)
        redirect_to(update_redirect_path, status: :see_other)
      end

      private

      def set_comment
        @comment = Comment.find(params.expect(:id))
      end

      def update_redirect_path
        params[:return_to_queue].present? ? queue_redirect_path : review_comment_path(@comment)
      end
    end
  end
end
