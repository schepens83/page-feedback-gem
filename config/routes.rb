# frozen_string_literal: true

PageFeedback::Engine.routes.draw do
  root to: "review/pages#index"
end
