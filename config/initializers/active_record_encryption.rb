Rails.application.config.after_initialize do
  derive = ->(purpose) { Rails.application.key_generator.generate_key("shango/active_record_encryption/#{purpose}", 32).unpack1("H*") }
  keys = Shango::EncryptionKeys.resolve(derive:)
  encryption = ActiveRecord::Encryption.config
  encryption.primary_key = keys[:primary_key]
  encryption.deterministic_key = keys[:deterministic_key]
  encryption.key_derivation_salt = keys[:key_derivation_salt]
end
