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

  resources :submissions
  resources :users

  # OmniAuth routes
  get "/auth/:provider/callback", to: "sessions#create"
  # Rep el callback després que OmniAuth processi el codi.

  get "/auth/failure", to: "sessions#failure"
  # Gestiona cancel·lacions o errors del proveïdor.

  post "/logout", to: "sessions#destroy", as: :logout
  # Logout amb POST perquè canvia l'estat de la sessió i queda protegit per CSRF.
end
