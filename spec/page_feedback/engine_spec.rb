# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Engine do
  it "boots with the isolated engine mounted" do
    expect(described_class).to be_isolated
    expect(described_class.engine_name).to eq("page_feedback")
    expect(described_class.routes.url_helpers).to respond_to(:root_path)
  end

  it "inherits engine controllers from the host application controller" do
    expect(PageFeedback::ApplicationController.superclass).to equal(ApplicationController)
  end

  it "composes the engine importmap and watches its JavaScript" do
    importmap_path = described_class.root.join("config/importmap.rb")
    javascript_path = described_class.root.join("app/assets/javascripts")

    expect(Rails.application.config.importmap.paths).to include(importmap_path)
    expect(Rails.application.config.importmap.cache_sweepers).to include(javascript_path)
    expect(Rails.application.importmap.packages).to include(
      "page_feedback/controllers/capture_controller",
      "page_feedback/review_highlight"
    )
  end
end
