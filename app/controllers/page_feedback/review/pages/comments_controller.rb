# frozen_string_literal: true

module PageFeedback
  module Review
    # Review resources nested beneath one encoded local page.
    module Pages
      # Presents one filtered page queue with safe in-context replay.
      class CommentsController < BaseController
        # Render the current queue item and previous/next navigation.
        #
        # @return [void]
        def index
          @page_key = params.expect(:page_key)
          @page_path = Comment.page_path_from_key!(@page_key)
          @filter = review_filter
          @category = review_category
          @status_counts = Comment.where(page_path: @page_path).group(:status).count
          assign_queue
        end

        private

        def assign_queue
          queue = queue_comments
          @total = queue.length
          return if queue.empty?

          position = requested_position(queue)
          assign_current(queue, position)
        end

        def queue_comments
          filtered_comments(Comment.where(page_path: @page_path)).includes(:export_items).recent.to_a
        end

        def requested_position(queue)
          requested_id = Integer(params[:id], exception: false)
          queue.index { |comment| comment.id == requested_id } || 0
        end

        def assign_current(queue, position)
          @current = queue.fetch(position)
          @position = position + 1
          @previous = queue[position - 1] if position.positive?
          @next = queue[position + 1]
          @iframe_src = replay_path(@current)
        end

        def replay_path(comment)
          query = {
            page_feedback_replay: 1,
            page_feedback_selector: comment.css_selector.presence,
            page_feedback_scroll: comment.context["scroll_y"]
          }.compact
          "#{comment.page_path}?#{query.to_query}"
        end
      end
    end
  end
end
