Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "galaxies#show"

  resources :galaxies, only: [ :show ] do
    resources :fleets, only: [ :create ]
    resources :sectors, only: %i[show] do
      resources :shipyard, only: %i[create]
    end
  end
end
