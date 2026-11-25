Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # Raíz de la aplicación apuntando al listado de submissions
  root "submissions#index"

  get "/news", to: "submissions#index", as: :news
  get "/submit", to: "submissions#new", as: :submit
  get "/newest", to: "submissions#newest", as: :newest
  get "/search", to: "submissions#search", as: :search
  get "/newcomments", to: "comments#index", as: :comments
  get "/threads", to: "comments#threads", as: :threads
  get "/ask", to: "submissions#ask", as: :ask
  get "/hidden", to: "submission_hides#index", as: :hidden_submissions

  resources :submissions do
    resource :favorite, only: %i[create destroy], controller: "favorites"
    resource :hide, only: %i[create destroy], controller: "submission_hides"
    resource :vote, only: %i[ create destroy ], controller: "submission_votes"
    resources :comments, only: %i[ show new create edit update destroy ] do
      resource :favorite, only: %i[create destroy], controller: "favorites"
      resource :vote, only: %i[ create destroy ], controller: "comment_votes"
    end
  end
  resources :users, except: %i[ new create ] do
    member do
      get :submissions
      get :comments
      get :favorites
      get :favorite_comments
      get :upvoted
      get :upvoted_comments
    end
  end

  # API REST (api/api.yaml). Autenticació amb la capçalera X-API-Key (Api::BaseController).
  namespace :api, defaults: { format: :json } do
    get "newest", to: "newest#index"
    # Perfils i els seus llistats (Taiga #69): /api/users/:id i /api/users/:id/<llista>
    resources :users, only: %i[ show update ] do
      member do
        get :submissions
        get :comments
        get :favorites
        get :favorite_comments
        get :upvoted
        get :upvoted_comments
        get :hidden
      end
      # Avatar i banner (Taiga #70): PUT (multipart) i DELETE /api/users/:user_id/avatar|banner
      resource :avatar, only: %i[ update destroy ], controller: "user_images", defaults: { kind: "avatar" }
      resource :banner, only: %i[ update destroy ], controller: "user_images", defaults: { kind: "banner" }
    end
    get "ask", to: "ask#index"
    get "threads", to: "comments#threads"
    resources :submissions, only: %i[index show create update destroy] do
      resource :vote, only: %i[create destroy], controller: "submission_votes"
      resource :hide, only: %i[create destroy], controller: "hidden_submissions"
      resources :comments, only: %i[create]
    end
    resources :comments, only: %i[index show update destroy] do
      resource :vote, only: %i[create destroy], controller: "comment_votes"
    end
  end

  # OmniAuth routes
  get "/auth/:provider/callback", to: "sessions#create"
  # Rep el callback després que OmniAuth processi el codi.

  get "/auth/failure", to: "sessions#failure"
  # Gestiona cancel·lacions o errors del proveïdor.

  post "/logout", to: "sessions#destroy", as: :logout
  # Logout amb POST perquè canvia l'estat de la sessió i queda protegit per CSRF.
end
