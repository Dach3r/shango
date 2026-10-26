Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }, failure_app: "LocalizedFailureApp"

  root to: "overview#show"

  resources :projects, only: %i[index new create]
  resource :current_project, only: :update
  resource :preferences, only: :update

  scope module: :projects do
    resources :environments, except: :show
    resource :current_environment, only: :update
    resource :membership, only: %i[edit update]
  end

  namespace :workbench do
    root to: "workspaces#show"

    resources :collections, except: %i[index show] do
      resources :folders, only: %i[new create]
      resources :requests, only: %i[new create]
      resource :curl_import, only: %i[new create]
    end

    resources :drafts, only: :create

    resources :folders, only: %i[edit update destroy] do
      resource :position, only: :update, module: :folders
    end

    resources :requests, only: %i[show update destroy] do
      scope module: :requests do
        resources :executions, only: %i[create show]
        resource :closure, only: :new
        resource :tab, only: :destroy
        resource :duplication, only: :create
        resource :position, only: :update
        resource :placement, only: %i[new update]
        resource :curl_export, only: :show
      end
    end

    namespace :oauth2 do
      resource :token, only: %i[create destroy]
      resource :authorization, only: :create
      resource :callback, only: :show
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
