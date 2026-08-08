# frozen_string_literal: true

require "nokogiri"
require "spec_helper"

RSpec.describe "page-feedback.html" do
  subject(:document) { Nokogiri::HTML5(File.read("page-feedback.html")) }

  it "is a self-contained Phase 2 report" do
    expect(document.at_css("title").text).to include("PageFeedback", "Phase 2")
    expect(document.css("script[src], link[rel='stylesheet']")).to be_empty
    expect(document.text).to include("Phase 2 complete", "58 examples, 0 failures")
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
