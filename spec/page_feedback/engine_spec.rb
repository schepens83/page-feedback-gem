# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Engine do
  let(:browser_modules) do
    %w[
      page_feedback/capture_controller_support page_feedback/capture_mode_status
      page_feedback/clipboard page_feedback/context_recorder
      page_feedback/controllers/capture_controller page_feedback/controllers/copy_controller
      page_feedback/element_capture
      page_feedback/feedback_picker page_feedback/review_highlight page_feedback/visual_viewport
    ]
  end

  it "boots with the isolated engine mounted" do
    expect(described_class).to be_isolated
    expect(described_class.engine_name).to eq("page_feedback")
    expect(described_class.routes.url_helpers).to respond_to(:root_path)
  end

  it "inherits engine controllers from the host application controller" do
    expect(PageFeedback::ApplicationController.superclass).to equal(ApplicationController)
  end

  it "registers Markdown responses on every supported Rails version" do
    expect(Mime::Type.lookup_by_extension(:md).to_s).to eq("text/markdown")
  end

  it "registers the engine importmap and watches its JavaScript" do
    importmap_path = described_class.root.join("config/importmap.rb")
    javascript_path = described_class.root.join("app/assets/javascripts")

    expect(Rails.application.config.importmap.paths).to include(importmap_path)
    expect(Rails.application.config.importmap.cache_sweepers).to include(javascript_path)
  end

  it "pins the browser modules and Stimulus runtime" do
    expect(Rails.application.importmap.packages).to include(*browser_modules)
    expect(Rails.application.importmap.packages).to include("@hotwired/stimulus")
  end

  it "makes browser assets resolvable through Propshaft" do
    assets = %w[
      page_feedback/page_feedback.css page_feedback/element_capture.js
      page_feedback/controllers/capture_controller.js stimulus.min.js
    ].map { |path| Rails.application.assets.load_path.find(path) }

    expect(assets).to all(be_present)
  end

  it "pins every internal module imported by the capture controller" do
    controller_source = described_class.root.join(
      "app/assets/javascripts/page_feedback/controllers/capture_controller.js"
    ).read
    imported_modules = controller_source.scan(%r{from "(page_feedback/[^"]+)"}).flatten

    expect(Rails.application.importmap.packages.keys).to include(*imported_modules)
  end
end
