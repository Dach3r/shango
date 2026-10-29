Rails.application.routes.draw do
  devise_for :users, path_names: { edit: "settings" }, controllers: { registrations: "users/registrations" }, failure_app: "LocalizedFailureApp"

  authenticated :user do
    root to: redirect("/workbench")
  end

  devise_scope :user do
    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end
  end

  resources :projects, only: %i[new create]
  resource :current_project, only: :update
  resource :preferences, only: :update
  resource :invitation_acceptance, only: %i[show create]
  resource :account, only: :show, module: :users

  scope module: :projects do
    resources :environments, except: :show do
      resources :variables, only: %i[create update], module: :environments
    end
    resource :current_environment, only: :update
    resources :cookies, except: :show
    resource :cookie_jar, only: :destroy
    resource :membership, only: %i[edit update], path_names: { edit: "settings" }
    resources :members, only: %i[index update destroy]
    resource :leave, only: :create
    resource :ownership_transfer, only: :create
    resources :invitations, only: %i[create destroy]
    resources :audit_events, only: :index
    resource :theme, only: %i[edit update], path_names: { edit: "settings" }
  end

  namespace :workbench do
    root to: "workspaces#show"

    resources :collections, except: %i[index show] do
      resources :folders, only: %i[new create]
      resources :requests, only: %i[new create]
      resource :curl_import, only: %i[new create]
      resources :exports, only: %i[new create]
    end

    resources :exports, only: :show do
      resource :download, only: :show, module: :exports
    end

    resource :import, only: %i[new create]

    resources :drafts, only: :create
    resource :tabs, only: :destroy

    resources :folders, only: %i[edit update destroy] do
      resource :position, only: :update, module: :folders
    end

    resources :requests, only: %i[show update destroy] do
      scope module: :requests do
        resources :executions, only: %i[create show] do
          resource :result, only: :show, module: :executions
          resource :cancellation, only: :create, module: :executions
          resources :saves, only: :create, module: :executions
        end
        resource :closure, only: :new
        resource :tab, only: :destroy
        resource :draft, only: %i[update destroy]
        resource :settings, only: :update
        resource :duplication, only: :create
        resource :position, only: :update
        resource :placement, only: %i[new update]
        resource :curl_export, only: :show
        resource :response_reference, only: :show
      end
    end

    namespace :oauth2 do
      resource :token, only: %i[create destroy]
      resource :authorization, only: :create
      resource :callback, only: :show
    end
  end

  namespace :network do
    root to: "workspaces#show"

    resources :dns_checks, only: :create
    resources :port_checks, only: :create
    resources :pings, only: :create
    resources :subnets, only: :create
    resources :tls_checks, only: :create
    resources :email_checks, only: :create
    resources :lookups, only: :create
    resources :checks, only: %i[show destroy]
    resource :history, only: :destroy
    get ":kind", to: "workspaces#show", constraints: { kind: Regexp.union(Network::Tools.names) }, as: :workspace
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "ready", to: "health#show"
end
