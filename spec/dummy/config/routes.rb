# frozen_string_literal: true

Rails.application.routes.draw do
  mount PageFeedback::Engine => "/feedback"
  root "pages#show"
end
