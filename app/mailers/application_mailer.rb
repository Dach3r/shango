class ApplicationMailer < ActionMailer::Base
  default from: -> { Shango::Mailing.sender }
  layout "mailer"
end
