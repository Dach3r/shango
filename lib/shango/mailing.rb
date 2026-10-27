module Shango
  # Outgoing email is optional: features that need it (email confirmation, password reset, unlock links)
  # only switch on when the operator configures SMTP through the environment.
  module Mailing
    class << self
      def enabled?
        ENV["SHANGO_SMTP_ADDRESS"].present?
      end

      # Needs SMTP; SHANGO_REQUIRE_EMAIL_CONFIRMATION=false lets the operator keep mail without enforcing it.
      def confirmation_required?
        enabled? && ActiveModel::Type::Boolean.new.cast(ENV.fetch("SHANGO_REQUIRE_EMAIL_CONFIRMATION", "true")) != false
      end

      def sender
        ENV.fetch("SHANGO_MAIL_FROM", "shango@localhost")
      end

      def url_options
        { host: ENV.fetch("SHANGO_HOST", "localhost"), protocol: ENV.fetch("SHANGO_PROTOCOL", "https") }
      end

      def smtp_settings
        return unless enabled?

        {
          address: ENV.fetch("SHANGO_SMTP_ADDRESS"), port: ENV.fetch("SHANGO_SMTP_PORT", 587).to_i, domain: ENV["SHANGO_SMTP_DOMAIN"].presence,
          user_name: ENV["SHANGO_SMTP_USERNAME"].presence, password: ENV["SHANGO_SMTP_PASSWORD"].presence,
          authentication: ENV.fetch("SHANGO_SMTP_AUTHENTICATION", "plain").to_sym,
          enable_starttls_auto: ActiveModel::Type::Boolean.new.cast(ENV.fetch("SHANGO_SMTP_STARTTLS", "true")) != false
        }.compact
      end
    end
  end
end
