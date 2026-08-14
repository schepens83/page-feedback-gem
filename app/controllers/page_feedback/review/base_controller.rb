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
        return review_pages_path(query) if params[:page_key].blank?

        page_queue_redirect_path(query)
      end

      def page_queue_redirect_path(query)
        if params[:next_id].present?
          return review_page_comments_path(params[:page_key], query.merge(id: params[:next_id]))
        end

        page_path = Comment.page_path_from_key!(params[:page_key])
        next_page_key = next_matching_page_key(excluding: page_path)
        return review_page_comments_path(next_page_key, query) if next_page_key

        review_pages_path(query)
      end

      def next_matching_page_key(excluding:)
        comment = filtered_comments.where.not(page_path: excluding).recent.first
        Comment.page_key(comment.page_path) if comment
      end
    end
  end
end
