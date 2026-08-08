# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |number| "reviewer-#{number}@example.test" }
  end
end
