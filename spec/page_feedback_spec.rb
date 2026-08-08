# frozen_string_literal: true

require "spec_helper"
require "page_feedback"

RSpec.describe PageFeedback do
  after { described_class.reset_configuration! }

  it "exposes one configurable object" do
    yielded_configuration = nil

    result = described_class.configure do |configuration|
      yielded_configuration = configuration
      configuration.default_category = "bug"
    end

    expect(yielded_configuration).to equal(described_class.configuration)
    expect(result).to equal(described_class.configuration)
    expect(described_class.configuration.default_category).to eq("bug")
  end

  it "resets configuration for test and host isolation" do
    original_configuration = described_class.configuration

    reset_configuration = described_class.reset_configuration!

    expect(reset_configuration).to be_a(PageFeedback::Configuration)
    expect(reset_configuration).not_to equal(original_configuration)
  end
end
