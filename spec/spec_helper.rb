# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.order = :random
end
