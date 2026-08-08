# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rails", "~> #{ENV.fetch('RAILS_VERSION')}.0" if ENV["RAILS_VERSION"]

group :development, :test do
  gem "rbs", ">= 3.8", require: false
  gem "rspec-rails", ">= 7.1"
  gem "rubocop", ">= 1.75", require: false
  gem "rubocop-rails", ">= 2.30", require: false
  gem "rubocop-rspec", ">= 3.5", require: false
  gem "sqlite3", ">= 2.1"
  gem "yard", ">= 0.9.37", require: false
end
