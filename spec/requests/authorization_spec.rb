# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback authorization" do
  after { PageFeedback.reset_configuration! }

  def post_capture
    original_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    post "/feedback/comments", params: open_capture_params
  ensure
    ActionController::Base.allow_forgery_protection = original_setting
  end

  def open_capture_params
    { comment: { comment_text: "Open capture", category: "idea", page_path: "/open" } }
  end

  it "preserves host CSRF protection" do
    post "/feedback/comments"

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "permits capture and review with open defaults" do
    post_capture
    expect(response).to have_http_status(:see_other)

    get "/feedback/review/pages"
    expect(response).to have_http_status(:not_implemented)
  end

  it "returns forbidden and passes the capture controller to host policy" do
    callback_controller = nil
    PageFeedback.configuration.capture_authorizer = lambda do |controller|
      callback_controller = controller
      false
    end

    post_capture

    expect(response).to have_http_status(:forbidden)
    expect(callback_controller).to be_a(PageFeedback::CommentsController)
  end

  it "returns forbidden and passes the review controller to host policy" do
    callback_controller = nil
    PageFeedback.configuration.review_authorizer = lambda do |controller|
      callback_controller = controller
      false
    end

    get "/feedback/review/pages"

    expect(response).to have_http_status(:forbidden)
    expect(callback_controller).to be_a(PageFeedback::Review::PagesController)
  end

  it "passes the engine controller to actor resolution" do
    callback_controller = nil
    PageFeedback.configuration.current_actor = lambda do |controller|
      callback_controller = controller
      :host_actor
    end
    controller = PageFeedback::CommentsController.new

    actor = controller.send(:page_feedback_current_actor)

    expect(actor).to eq(:host_actor)
    expect(callback_controller).to equal(controller)
  end
end
