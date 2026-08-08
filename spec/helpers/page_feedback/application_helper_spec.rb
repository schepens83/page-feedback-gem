# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::ApplicationHelper, type: :helper do
  it "exposes safe host layout integration stubs" do
    expect(helper.page_feedback_head).to be_html_safe
    expect(helper.page_feedback_widget).to be_html_safe
  end

  it "makes the integration helpers available to the host" do
    expect(ApplicationController.helpers).to respond_to(
      :page_feedback_head,
      :page_feedback_widget
    )
  end
end
