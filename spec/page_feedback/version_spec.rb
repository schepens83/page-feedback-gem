# frozen_string_literal: true

require "spec_helper"
require "page_feedback/version"

RSpec.describe "PageFeedback::VERSION" do
  it "starts at the planned first-release version" do
    expect(PageFeedback::VERSION).to eq("0.1.0")
  end
end
