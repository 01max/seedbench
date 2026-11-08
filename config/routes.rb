Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "home#show"
  resource :session, only: %i[new create destroy]
  resource :appearance, only: :show
end
