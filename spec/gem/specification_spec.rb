# frozen_string_literal: true

require "spec_helper"
require "rubygems"

RSpec.describe Gem::Specification do
  subject(:files) { described_class.load("page_feedback.gemspec").files }

  it "includes documentation" do
    expect(files).to include(
      "README.md",
      "docs/IMPLEMENTATION_PLAN.md",
      "docs/WHY.md",
      "page-feedback.html"
    )
  end

  it "includes runtime trees" do
    expect(files).to include(
      "app/assets/stylesheets/page_feedback/page_feedback.css",
      "db/migrate/.keep",
      "exe/page_feedback"
    )
  end
end
