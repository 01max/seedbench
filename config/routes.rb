Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check
  root 'releases#index'
  devise_for :operators, skip: :all
  devise_scope :operator do
    get 'session/new', to: 'sessions#new', as: :new_operator_session
    post 'session', to: 'sessions#create', as: :operator_session
    delete 'session', to: 'sessions#destroy', as: :destroy_operator_session
  end
  resource :settings, only: %i[show update]
  resources :uploads, only: :create
  resources :releases, only: %i[index show update] do
    resource :ai_action, only: %i[show create]
    resource :duplicate_review, only: %i[show create]
    resource :cover_review, only: %i[show create]
    resource :selected_cover, only: :show
    resource :preparation, only: :show
    resource :content_action, only: %i[show create]
    resource :content_preview, only: :create
    resource :evidence, controller: 'ebook_evidence', only: %i[show create]
    resources :fact_reviews, controller: 'ebook_reviews', only: :create
    resources :cover_candidates, controller: 'ebook_covers', only: :show
    resources :checks, controller: 'release_checks', only: :create
    resource :status, controller: 'release_statuses', only: :show
    member do
      patch 'actions/:kind', to: 'release_actions#create', as: :action
    end
    resource :connections, controller: 'release_connections', only: %i[show update]
  end
  resources :provider_connections, path: 'settings/connections', only: :create do
    member do
      patch :rotate
      patch :configure
      patch :complete
      post :check
    end
  end
  resource :appearance, only: :show
end
