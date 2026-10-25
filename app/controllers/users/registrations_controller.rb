class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def update_resource(resource, params)
    params = params.except(:current_password)
    params = params.except(:password, :password_confirmation) if params[:password].blank?

    resource.update(params)
  end
end
