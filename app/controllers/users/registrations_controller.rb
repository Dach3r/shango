class Users::RegistrationsController < Devise::RegistrationsController
  include ProjectContext

  TABS = %w[profile preferences security].freeze

  layout -> { action_name.in?(%w[edit update]) ? "app" : "devise" }

  before_action :require_project, only: %i[edit update]
  before_action :set_tab, only: %i[edit update]

  protected

  def after_sign_up_path_for(_resource)
    new_project_path
  end

  def after_update_path_for(_resource)
    edit_user_registration_path(tab: @tab)
  end

  def update_resource(resource, params)
    params = params.except(:current_password)
    params = params.except(:password, :password_confirmation) if params[:password].blank?

    resource.update(params)
  end

  private

  def set_tab
    @tab = params[:tab].presence_in(TABS) || TABS.first
  end
end
