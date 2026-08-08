# frozen_string_literal: true

require "spec_helper"
require "page_feedback"

RSpec.describe PageFeedback::Configuration do
  subject(:configuration) { described_class.new }

  describe "defaults" do
    it "allows anonymous capture and review" do
      controller = Object.new

      expect(configuration.current_actor.call(controller)).to be_nil
      expect(configuration.capture_authorizer.call(controller)).to be(true)
      expect(configuration.review_authorizer.call(controller)).to be(true)
    end

    it "provides category defaults" do
      expect(configuration.categories).to eq(
        "bug" => "Bug",
        "idea" => "Idea",
        "question" => "Question",
        "compliment" => "Compliment"
      )
      expect(configuration.default_category).to eq("idea")
    end

    it "provides browser integration defaults" do
      expect(configuration.activation_shortcut).to eq(alt: true, key: "f")
      expect(configuration.trigger_visible).to be(true)
      expect(configuration.ignored_css_classes).to eq([])
    end

    it "provides actor labels" do
      actor = Struct.new(:email).new("reviewer@example.test")

      expect(configuration.actor_label.call(actor)).to eq("reviewer@example.test")
      expect(configuration.actor_label.call(123)).to eq("123")
    end

    it "provides extension callbacks" do
      expect(configuration.source_locator.call(Object.new)).to be_nil
      expect(configuration.export_formatter).to respond_to(:call)
    end

    it "does not share mutable defaults between instances" do
      other_configuration = described_class.new

      configuration.categories["other"] = "Other"
      configuration.ignored_css_classes << "runtime-class"

      expect(other_configuration.categories).not_to have_key("other")
      expect(other_configuration.ignored_css_classes).to be_empty
    end
  end
end
