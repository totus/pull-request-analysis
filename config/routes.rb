Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "repositories#index"

  resources :repositories, only: [ :index, :create, :show ] do
    post :refresh, on: :member
  end

  resources :pull_requests, only: :show
end
