Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "pwa#service_worker", as: :pwa_service_worker

  # The planet overview is the main management screen, so it is also the landing page.
  root "planets#show"

  get "planet", to: "planets#show", as: :planet
  get "planet/:section", to: "planets#structures", as: :planet_structures,
      constraints: { section: /resources|facilities|defences/ }
  patch "planet/structures/:id", to: "planet_structures#update", as: :planet_structure

  # Research is empire-wide, so it sits outside the planet routes.
  get "research", to: "research#show", as: :research
  post "research/:id", to: "research#create", as: :start_research

  get "shipyard", to: "shipyard#show", as: :shipyard
  post "shipyard/:id", to: "shipyard#create", as: :build_ships

  # Fleets belong to the empire, not a planet, so they sit alongside research.
  get "fleets", to: "fleets#index", as: :fleets
  post "fleets", to: "fleets#create", as: :dispatch_fleet

  # Administration is account-wide, not per galaxy: an admin sees every galaxy and every
  # account. Read-only — admin itself is granted from the console, never from the game.
  namespace :admin do
    root "dashboard#show", as: :dashboard
  end

  # The lobby is where you land without an empire: your galaxies, the ones you can spawn
  # into, and — for an admin — generating a new one and inspecting how it came out.
  resources :galaxies, only: %i[index new create show] do
    member do
      get :preview
      post :join
    end

    resources :systems, only: %i[show]
  end
end
