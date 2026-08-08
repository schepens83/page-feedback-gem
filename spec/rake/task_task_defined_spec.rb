# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe Rake::Task, ".task_defined?" do
  before do
    Rails.application.load_tasks unless described_class.task_defined?("page_feedback:doctor")
  end

  it "exposes doctor and Rails' engine migration installer" do
    expect(described_class).to be_task_defined("page_feedback:doctor")
    expect(described_class).to be_task_defined("page_feedback:install:migrations")
  end
end
