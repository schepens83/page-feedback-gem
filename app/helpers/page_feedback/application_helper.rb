# frozen_string_literal: true

module PageFeedback
  # View integration helpers for the isolated engine.
  module ApplicationHelper
    # Placeholder for engine stylesheet and replay module tags.
    #
    # @return [ActiveSupport::SafeBuffer]
    def page_feedback_head
      ActiveSupport::SafeBuffer.new
    end

    # Placeholder for capture UI markup.
    #
    # @return [ActiveSupport::SafeBuffer]
    def page_feedback_widget
      ActiveSupport::SafeBuffer.new
    end
  end
end
