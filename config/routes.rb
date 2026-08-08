# frozen_string_literal: true

PageFeedback::Engine.routes.draw do
  resources :comments, only: :create

  namespace :review do
    root "pages#index"
    resources :pages, only: :index
  end

  root to: "review/pages#index"
end
