# frozen_string_literal: true

module PageFeedback
  # Receives feedback capture requests. Persistence is implemented in Phase 3.
  class CommentsController < ApplicationController
    before_action :ensure_capture_authorized, only: :create

    def create
      head :not_implemented
    end
  end
end
