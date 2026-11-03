# frozen_string_literal: true

module PageFeedback
  module Review
    # Previews, creates, and serves immutable export snapshots.
    class ExportsController < BaseController
      before_action :set_export, only: :show

      # List immutable export history newest first.
      #
      # @return [void]
      def index
        @exports = Export.includes(:export_items).order(created_at: :desc)
      end

      # Show export membership or serve the exact stored Markdown body.
      #
      # @return [void]
      def show
        respond_to do |format|
          format.html
          format.md { send_stored_markdown }
        end
      end

      # Preview selected ready revisions without persistence.
      #
      # @return [void]
      def new
        @comments = selected_ready_comments(default_to_all: true)
        @preview_body = PageFeedback.configuration.export_formatter.call(
          comments: @comments,
          generated_at: Time.current
        )
      end

      # Persist one immutable export from the exact selected order.
      #
      # @return [void]
      def create
        export = Export.create_from!(
          comments: selected_ready_comments,
          actor: page_feedback_current_actor
        )
        redirect_to review_export_path(export), status: :see_other
      end

      private

      def set_export
        @export = Export.includes(export_items: :comment).find(params.expect(:id))
      end

      def selected_ready_comments(default_to_all: false)
        ids = selected_comment_ids
        ids = Comment.ready_for_export.recent.pluck(:id) if default_to_all && ids.empty?
        comments_by_id = Comment.ready_for_export.where(id: ids).index_by(&:id)
        ids.filter_map { |id| comments_by_id[id] }
      end

      def send_stored_markdown
        send_data(
          @export.body,
          filename: "page-feedback-export-#{@export.id}.md",
          type: "text/markdown; charset=utf-8",
          disposition: "attachment"
        )
      end
    end
  end
end
