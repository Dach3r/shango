Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }, failure_app: "LocalizedFailureApp"

  devise_scope :user do
    authenticated do
      root to: "projects#index", as: :authenticated_root
    end

    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end
  end

  resource :locale, only: :update

  get "up" => "rails/health#show", as: :rails_health_check
end
