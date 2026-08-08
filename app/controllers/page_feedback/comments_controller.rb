# frozen_string_literal: true

require "json"

module PageFeedback
  # Authorizes, normalizes, and persists feedback captured on host pages.
  class CommentsController < ApplicationController
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

    def normalize_context(raw_context)
      context = context_hash(raw_context)
      normalized_scalar_context(context).merge(
        normalized_collection_context(context)
      )
    end

    def normalized_scalar_context(context)
      {
        "parent_html" => context_value(context, "parent_html", "parentHTML"),
        "viewport" => context["viewport"],
        "scroll_y" => normalized_integer(context_value(context, "scroll_y", "scrollY"))
      }
    end

    def normalized_collection_context(context)
      {
        "console_errors" => normalize_context_collection(
          context_value(context, "console_errors", "consoleErrors"),
          content_key: "message"
        ),
        "navigation_history" => normalize_context_collection(
          context_value(context, "navigation_history", "navigationHistory"),
          content_key: "url"
        )
      }
    end

    def persist_comment
      @comment.save
    end

    def context_hash(raw_context)
      value = raw_context.is_a?(String) ? JSON.parse(raw_context) : raw_context
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value.is_a?(Hash) ? value.stringify_keys : {}
    rescue JSON::ParserError, TypeError
      {}
    end

    def context_value(context, snake_case_key, camel_case_key)
      context.key?(snake_case_key) ? context[snake_case_key] : context[camel_case_key]
    end

    def normalize_context_collection(value, content_key:)
      collection = value.is_a?(String) ? JSON.parse(value) : value
      return [] unless collection.is_a?(Array)

      collection.filter_map do |entry|
        normalized_context_entry(entry, content_key:)
      end
    rescue JSON::ParserError, TypeError
      []
    end

    def normalized_context_entry(entry, content_key:)
      entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
      return unless entry.is_a?(Hash)

      attributes = entry.stringify_keys
      timestamp = context_value(attributes, "timestamp_ms", "timestampMs")
      attributes.slice(content_key).merge("timestamp_ms" => normalized_integer(timestamp))
    end

    def normalized_integer(value)
      Integer(value, exception: false)
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
