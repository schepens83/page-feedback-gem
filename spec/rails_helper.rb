# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
require "rspec/rails"
require "spec_helper"

ActiveRecord::Migration.maintain_test_schema!
FactoryBot.definition_file_paths << PageFeedback::Engine.root.join("spec/factories")
FactoryBot.find_definitions

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
