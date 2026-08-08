# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::ApplicationHelper, type: :helper do
  let(:capture_integration_attributes) do
    [
      'data-controller="page-feedback-capture"',
      "data-page-feedback-capture-controller-action-value=",
      "data-page-feedback-capture-default-category-value=\"idea\"",
      "data-page-feedback-capture-ignored-classes-value=\"[]\"",
      "data-page-feedback-capture-shortcut-value=",
      'id="page_feedback_modal_comment"',
      'action="/feedback/comments"'
    ]
  end

  after { PageFeedback.reset_configuration! }

  it "emits namespaced head assets only once" do
    first_render = helper.page_feedback_head

    expect(first_render).to be_html_safe
    expect(first_render).to include("page_feedback/page_feedback", "page_feedback/review_highlight")
    expect(helper.page_feedback_head).to be_blank
  end

  it "renders the capture form with open defaults" do
    widget = helper.page_feedback_widget

    expect(widget).to be_html_safe
    expect(widget).to include(*capture_integration_attributes)
  end

  it "can keep keyboard capture while hiding the floating trigger" do
    PageFeedback.configuration.trigger_visible = false

    widget = helper.page_feedback_widget

    expect(widget).to include(*capture_integration_attributes)
    expect(widget).not_to include("Give page feedback")
  end

  it "omits the widget when host capture policy denies access" do
    callback_controller = nil
    PageFeedback.configuration.capture_authorizer = lambda do |controller|
      callback_controller = controller
      false
    end

    expect(helper.page_feedback_widget).to be_blank
    expect(callback_controller).to be_a(PageFeedback::CommentsController)
  end

  it "omits capture chrome in replay mode" do
    allow(helper).to receive(:params).and_return(ActionController::Parameters.new(page_feedback_replay: "1"))

    expect(helper.page_feedback_widget).to be_blank
  end

  it "makes the integration helpers available to the host" do
    expect(ApplicationController.helpers).to respond_to(
      :page_feedback_head,
      :page_feedback_widget
    )
  end
end
