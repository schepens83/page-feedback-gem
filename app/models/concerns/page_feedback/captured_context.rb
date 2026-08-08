# frozen_string_literal: true

module PageFeedback
  # Size validation for untrusted browser and DOM capture fields.
  module CapturedContext
    extend ActiveSupport::Concern

    included do
      validates :comment_text, presence: true, length: { maximum: Comment::MAX_COMMENT_TEXT_LENGTH }
      validates :page_path, length: { maximum: Comment::MAX_PAGE_PATH_LENGTH }
      validates :page_title, length: { maximum: Comment::MAX_PAGE_TITLE_LENGTH }, allow_nil: true
      validates :controller_action, length: { maximum: Comment::MAX_CONTROLLER_ACTION_LENGTH }, allow_nil: true
      validates :css_selector, length: { maximum: Comment::MAX_CSS_SELECTOR_LENGTH }, allow_nil: true
      validates :element_html, length: { maximum: Comment::MAX_ELEMENT_HTML_LENGTH }, allow_nil: true
      validate :captured_context_within_limits
    end

    private

    def captured_context_within_limits
      validate_context_length("parent_html", Comment::MAX_PARENT_HTML_LENGTH, "parent HTML is too long")
      validate_context_count("console_errors", Comment::MAX_CONSOLE_ERRORS, "has too many console errors")
      validate_context_count("navigation_history", Comment::MAX_NAVIGATION_EVENTS, "has too many navigation events")
    end

    def validate_context_length(key, maximum, message)
      errors.add(:context, message) if context[key].to_s.length > maximum
    end

    def validate_context_count(key, maximum, message)
      errors.add(:context, message) if context[key].to_a.length > maximum
    end
  end
end
