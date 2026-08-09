# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::ActorLabel do
  it "returns nil without an actor" do
    expect(described_class.call(nil)).to be_nil
  end

  it "prefers an explicit engine label over other readers" do
    actor = Class.new do
      def to_page_feedback_label = "Release captain"
      def name = "Robin Vega"
    end.new

    expect(described_class.call(actor)).to eq("Release captain")
  end

  it "walks conventional display readers in order" do
    named = Struct.new(:name, :email).new("Robin Vega", "robin@example.test")
    mailed = Struct.new(:email).new("robin@example.test")

    expect(described_class.call(named)).to eq("Robin Vega")
    expect(described_class.call(mailed)).to eq("robin@example.test")
  end

  it "skips blank display readers" do
    actor = Struct.new(:name, :email).new("  ", "robin@example.test")

    expect(described_class.call(actor)).to eq("robin@example.test")
  end

  it "uses a to_s the class defines itself" do
    actor = Class.new do
      def to_s = "Robin Vega"
    end.new

    expect(described_class.call(actor)).to eq("Robin Vega")
    expect(described_class.call(123)).to eq("123")
  end

  it "identifies records that expose no display reader" do
    record_class = Class.new(User) do
      undef_method :email

      def self.model_name = ActiveModel::Name.new(self, nil, "Reviewer")
    end
    record = record_class.new
    record.id = 3

    expect(described_class.call(record)).to eq("Reviewer #3")
  end

  it "never leaks Ruby's inherited to_s" do
    unnamed = User.new
    unpersisted = Struct.new(:role).new("admin")

    expect(described_class.call(unnamed)).to eq("User")
    expect(described_class.call(unpersisted)).to eq("Unknown")
    expect(described_class.call(Object.new)).to eq("Object")
  end
end
