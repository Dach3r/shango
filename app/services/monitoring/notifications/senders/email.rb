module Monitoring
  module Notifications
    module Senders
      # An email to the channel's addresses; only when the installation has SMTP.
      module Email
        ERRORS = [Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError, Net::OpenTimeout, Net::ReadTimeout,
                  SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError].freeze

        module_function

        def call(message)
          return Result.failure(error: :mail_disabled, permanent: true) unless Shango::Mailing.enabled?

          MonitoringMailer.with(delivery: message.delivery).alert.deliver_now
          Result.success
        rescue *ERRORS => error
          Result.failure(error: :mail_failed, detail: error.class.name)
        end
      end
    end
  end
end
