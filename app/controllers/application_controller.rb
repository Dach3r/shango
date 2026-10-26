class ApplicationController < ActionController::Base
  include Localization
  include Theming

  stale_when_importmap_changes

  layout -> { "devise" if devise_controller? }

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  # Land on sign in directly so the "signed out" flash survives (root would redirect and drop it).
  def after_sign_out_path_for(_scope)
    new_user_session_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name])
  end
end
