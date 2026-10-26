# frozen_string_literal: true

# Secrets (variable values, auth credentials, OAuth tokens) are encrypted at rest.
# Self-hosted installs can set the three ACTIVE_RECORD_ENCRYPTION_* variables explicitly
# (generate them with `bin/rails db:encryption:init`); otherwise the keys are derived from
# secret_key_base, so rotating secret_key_base makes existing secrets unreadable.
Rails.application.config.after_initialize do
  derive = ->(purpose) { Rails.application.key_generator.generate_key("shango/active_record_encryption/#{purpose}", 32).unpack1("H*") }
  encryption = ActiveRecord::Encryption.config

  encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") { derive.call("primary_key") }
  encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") { derive.call("deterministic_key") }
  encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") { derive.call("key_derivation_salt") }
end
