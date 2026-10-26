class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def after_sign_up_path_for(_resource)
    new_project_path
  end

  def update_resource(resource, params)
    params = params.except(:current_password)
    params = params.except(:password, :password_confirmation) if params[:password].blank?

    resource.update(params)
  end
end
