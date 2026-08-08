# frozen_string_literal: true

require "nokogiri"
require "spec_helper"

RSpec.describe "page-feedback.html" do
  subject(:document) { Nokogiri::HTML5(File.read("page-feedback.html")) }

  it "is a self-contained Phase 8 adoption report" do
    expect(document.at_css("title").text).to include("PageFeedback", "Phase 8")
    expect(document.css("script[src], link[rel='stylesheet']")).to be_empty
    expect(document.text).to include(
      "Host cutover complete",
      "132 gem examples pass",
      "152 host",
      "Compatibility CI green",
      "MIT licensed",
      "0c7572b"
    )
  end

  it "links only to local documentation that exists" do
    links = document.css("a[href]").filter_map do |anchor|
      href = anchor["href"]
      href unless href.start_with?("#", "https://")
    end

    expect(links).not_to be_empty
    expect(links).to all(satisfy { |link| File.exist?(link) })
  end
end
