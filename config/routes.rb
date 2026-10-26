Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }, failure_app: "LocalizedFailureApp"

  root to: "overview#show"

  resources :projects, only: %i[index new create]
  resource :current_project, only: :update
  resource :preferences, only: :update

  get "up" => "rails/health#show", as: :rails_health_check
end
