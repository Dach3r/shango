# Devise ships its own controllers, so their limits are attached once they are loaded.
Rails.application.config.to_prepare do
  Devise::SessionsController.throttle :sign_in, only: :create
  Devise::PasswordsController.throttle :password_reset, only: :create
end
