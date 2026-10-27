class Users::RegistrationsController < Devise::RegistrationsController
  include ProjectContext

  TABS = %w[profile preferences security delete_account].freeze

  layout -> { action_name.in?(%w[edit update]) ? "app" : "devise" }

  throttle :sign_up, only: :create
  before_action :require_project, only: %i[edit update]
  before_action :set_tab, only: %i[edit update]

  def destroy
    result = Users::Destroy.call(user: resource, password: params[:current_password])
    return redirect_to(edit_user_registration_path(tab: "delete_account"), alert: destroy_failure(result), status: :see_other) if result.failure?

    sign_out
    set_flash_message! :notice, :destroyed
    redirect_to after_sign_out_path_for(resource_name), status: :see_other
  end

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

  def destroy_failure(result)
    t("devise.registrations.destroy.#{result.error}", projects: result.data[:projects]&.to_sentence)
  end

  def set_tab
    @tab = params[:tab].presence_in(TABS) || TABS.first
  end
end
