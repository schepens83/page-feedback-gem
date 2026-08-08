# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Run the dependency-free browser module test suite"
# Browser modules are intentionally tested without booting Rails.
# rubocop:disable Rails/RakeEnvironment
task :javascript do
  sh "npm test"
end
# rubocop:enable Rails/RakeEnvironment

task default: :spec
