Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "releases#index"
  devise_for :operators, skip: :all
  devise_scope :operator do
    get "session/new", to: "sessions#new", as: :new_operator_session
    post "session", to: "sessions#create", as: :operator_session
    delete "session", to: "sessions#destroy", as: :destroy_operator_session
  end
  resource :settings, only: %i[show update]
  resources :uploads, only: :create
  resources :releases, only: %i[index show] do
    resources :checks, controller: "release_checks", only: :create
    resource :connections, controller: "release_connections", only: %i[show update]
  end
  resources :provider_connections, path: "settings/connections", only: :create do
    member do
      patch :rotate
      patch :configure
      patch :complete
      post :check
    end
  end
  resource :appearance, only: :show
end
