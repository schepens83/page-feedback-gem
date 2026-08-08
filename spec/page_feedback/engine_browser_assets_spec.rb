# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Engine do
  let(:stylesheet) { File.read("app/assets/stylesheets/page_feedback/page_feedback.css") }
  let(:selectors) do
    stylesheet.scan(/([^{}]+)\{/).flatten.filter_map do |block_header|
      header = block_header.strip
      next if header.start_with?("@") || header.match?(/\A(?:from|to|\d+%)/)

      header.lines.map { |line| line.strip.delete_suffix(",") }.reject(&:empty?)
    end.flatten
  end

  it "namespaces every CSS custom property" do
    custom_properties = stylesheet.scan(/(?:var\(|^\s*)(--[a-z0-9-]+)/).flatten

    expect(custom_properties).not_to be_empty
    expect(custom_properties).to all(start_with("--page-feedback-"))
  end

  it "scopes every CSS selector to PageFeedback" do
    expect(selectors).not_to be_empty
    expect(selectors).to all(
      satisfy do |selector|
        selector == ":root" || selector.include?(".page-feedback-") || selector.include?("body.page-feedback-")
      end
    )
  end
end
