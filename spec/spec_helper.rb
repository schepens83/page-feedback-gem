# frozen_string_literal: true

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.order = :random
end
