Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "home#show"
  resource :session, only: %i[new create destroy]
  resource :settings, only: :show
  resources :provider_connections, path: "settings/connections", only: :create do
    member do
      patch :rotate
      patch :configure
      post :check
    end
  end
  resource :appearance, only: :show
end
