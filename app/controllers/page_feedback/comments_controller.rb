# frozen_string_literal: true

module PageFeedback
  # Authorizes, normalizes, and persists feedback captured on host pages.
  class CommentsController < ApplicationController
    include CommentContextNormalization

    # Browser-supplied comment fields accepted by the capture endpoint.
    CAPTURE_FIELDS = %i[
      comment_text category page_path page_title controller_action css_selector element_html
    ].freeze

    before_action :ensure_capture_authorized, only: :create

    # Persist feedback and respond in the requested Turbo, HTML, or JSON format.
    #
    # Actor identity and the initial review state are always assigned server-side.
    #
    # @return [void]
    def create
      @comment = Comment.new(normalized_comment_attributes)
      @comment.submitter = page_feedback_current_actor

      if persist_comment
        @form_comment = Comment.new
        respond_with_created_comment
      else
        @form_comment = @comment
        respond_with_invalid_comment
      end
    end

    private

    def normalized_comment_attributes
      submitted_comment = params.require(:comment)
      permitted_comment = submitted_comment.permit(*CAPTURE_FIELDS, context: {})
      permitted_comment.to_h.merge("context" => normalize_context(permitted_comment[:context]))
    end

    def persist_comment
      @comment.save
    end

    def respond_with_created_comment
      respond_to do |format|
        format.turbo_stream { render :create, status: :created }
        format.html { redirect_back_or_to root_path, status: :see_other }
        format.json { render json: { id: @comment.id, status: @comment.status }, status: :created }
      end
    end

    def respond_with_invalid_comment
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_content }
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: { errors: @comment.errors.to_hash }, status: :unprocessable_content }
      end
    end
  end
end
