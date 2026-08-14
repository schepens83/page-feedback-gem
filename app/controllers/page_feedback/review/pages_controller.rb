# frozen_string_literal: true

module PageFeedback
  module Review
    # Lists page-grouped feedback with review and export-state counts.
    class PagesController < BaseController
      # Render the filtered page overview.
      #
      # @return [void]
      def index
        @filter = review_filter
        @category = review_category
        @page_rows = ReviewPage.from_comments(filtered_comments.includes(:export_items).recent)
        @filter_counts = Comment::REVIEW_FILTERS.index_with do |filter|
          Comment.for_review_filter(filter).count
        end
        pending = Comment.pending
        pending = pending.by_category(@category) if @category
        @pending_count = pending.count
      end
    end
  end
end
