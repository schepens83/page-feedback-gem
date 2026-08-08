# frozen_string_literal: true

module PageFeedback
  # Host-authorized review resources.
  module Review
    # Applies host review authorization to every review resource.
    class BaseController < PageFeedback::ApplicationController
      before_action :ensure_review_authorized

      private

      def review_filter
        requested_filter = params[:filter].presence || params[:status].presence
        Comment::REVIEW_FILTERS.include?(requested_filter) ? requested_filter : "pending"
      end

      def review_category
        category = params[:category].presence
        PageFeedback.configuration.categories.key?(category) ? category : nil
      end

      def filtered_comments(relation = Comment.all)
        comments = relation.merge(Comment.for_review_filter(review_filter))
        review_category ? comments.by_category(review_category) : comments
      end

      def reviewer_attributes
        return {} if params[:comment].blank?

        params.expect(comment: %i[refined_text reviewer_notes])
      end

      def selected_comment_ids
        Array(params[:comment_ids].presence || params[:comment_ids_csv].to_s.split(","))
          .filter_map { |id| Integer(id, exception: false) }
          .select(&:positive?)
          .uniq
      end

      def queue_redirect_path
        query = { filter: review_filter, category: review_category }.compact
        query[:id] = params[:next_id] if params[:next_id].present?
        return review_page_comments_path(params[:page_key], query) if params[:page_key].present?

        review_pages_path(query)
      end
    end
  end
end
