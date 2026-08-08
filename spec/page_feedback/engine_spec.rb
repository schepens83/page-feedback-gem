# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Engine do
  it "boots with the isolated engine mounted" do
    expect(described_class).to be_isolated
    expect(described_class.engine_name).to eq("page_feedback")
    expect(described_class.routes.url_helpers).to respond_to(:root_path)
  end
end
