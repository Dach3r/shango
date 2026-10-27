# Devise ships its own controllers, so their limits and guards are attached once they are loaded.
Rails.application.config.to_prepare do
  Devise::SessionsController.throttle :sign_in, only: :create
  Devise::PasswordsController.throttle :password_reset, only: :create
  [Devise::PasswordsController, Devise::ConfirmationsController, Devise::UnlocksController].each { |controller| controller.include MailRequired }
end
