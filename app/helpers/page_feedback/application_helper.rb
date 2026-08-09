# frozen_string_literal: true

module PageFeedback
  # View integration helpers for the isolated engine.
  module ApplicationHelper
    # Emit the engine stylesheet and replay module tags once per request.
    #
    # @return [ActiveSupport::SafeBuffer]
    def page_feedback_head
      return ActiveSupport::SafeBuffer.new if request.env["page_feedback.head_rendered"]

      request.env["page_feedback.head_rendered"] = true
      safe_join(
        [
          stylesheet_link_tag("page_feedback/page_feedback", "data-turbo-track": "reload"),
          page_feedback_ignored_classes_meta,
          javascript_import_module_tag("page_feedback/review_highlight")
        ].compact
      )
    end

    # Render authorized capture UI at the engine's actual mount path.
    #
    # @return [ActiveSupport::SafeBuffer]
    def page_feedback_widget
      return ActiveSupport::SafeBuffer.new if page_feedback_replay?
      return ActiveSupport::SafeBuffer.new unless page_feedback_capture_authorized?

      render(
        "page_feedback/comments/widget",
        comment: PageFeedback::Comment.new,
        comments_path: page_feedback_mounted_routes.comments_path,
        controller_action: "#{controller.controller_path}##{controller.action_name}"
      )
    end

    # Path back to the host application when it defines a root route.
    #
    # @return [String, nil]
    def page_feedback_host_root_path
      main_app.root_path if main_app.respond_to?(:root_path)
    end

    private

    # Replay matching needs the same runtime classes capture strips, and the
    # replayed page is the host's, so the configuration travels in its head.
    def page_feedback_ignored_classes_meta
      ignored_classes = PageFeedback.configuration.ignored_css_classes
      return if ignored_classes.blank?

      tag.meta(name: "page-feedback-ignored-classes", content: ignored_classes.join(" "))
    end

    def page_feedback_replay?
      params[:page_feedback_replay].present?
    end

    def page_feedback_capture_authorized?
      PageFeedback.configuration.capture_authorizer.call(page_feedback_policy_controller)
    end

    def page_feedback_policy_controller
      PageFeedback::CommentsController.new.tap do |engine_controller|
        engine_controller.set_request!(controller.request)
        engine_controller.set_response!(controller.response)
      end
    end

    def page_feedback_mounted_routes
      controller.public_send(PageFeedback::Engine.engine_name)
    end
  end
end
