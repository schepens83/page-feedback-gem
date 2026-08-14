# frozen_string_literal: true

PageFeedback::Engine.routes.draw do
  resources :comments, only: :create

  namespace :review do
    root "pages#index"

    resources :pages, param: :key, only: :index do
      resources :comments, only: :index, module: :pages
    end

    resources :comments, only: %i[show update] do
      resource :approval, only: %i[create destroy], module: :comments
      resource :rejection, only: %i[create destroy], module: :comments
    end

    resources :bulk_approvals, only: :create
    resources :bulk_rejections, only: :create
    resources :queue_approvals, only: :create
    resources :exports, only: %i[index new create show]
  end

  root to: "review/pages#index"
end
