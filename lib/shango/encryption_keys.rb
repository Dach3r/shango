module Shango
  # Active Record Encryption keys. Production must pin them explicitly (a derived key dies with `secret_key_base`);
  # development and test derive them. Each variable may hold several comma-separated keys: the last (newest) one encrypts,
  # all of them decrypt, which is how keys are rotated (see `bin/rails shango:encryption:rotate`).
  class EncryptionKeys
    VARIABLES = {
      primary_key: "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
      deterministic_key: "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY",
      key_derivation_salt: "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"
    }.freeze
    ALLOW_DERIVED = "SHANGO_ALLOW_DERIVED_ENCRYPTION_KEYS".freeze

    class Missing < StandardError; end

    class << self
      # { primary_key:, deterministic_key:, key_derivation_salt: }. `derive` receives the purpose and returns a hex key.
      def resolve(env: ENV, production: Rails.env.production?, derive:)
        missing = VARIABLES.reject { |_name, variable| env[variable].present? }
        raise Missing, message(missing.values) if production && missing.any? && !allow_derived?(env)

        VARIABLES.to_h do |name, variable|
          keys = env[variable].to_s.split(",").map(&:strip).compact_blank
          [name, keys.empty? ? derive.call(name.to_s) : (keys.one? ? keys.first : keys)]
        end
      end

      private

      def allow_derived?(env)
        ActiveModel::Type::Boolean.new.cast(env[ALLOW_DERIVED]) == true
      end

      def message(missing)
        "Missing #{missing.to_sentence}. Production needs explicit Active Record Encryption keys: generate them with " \
          "`bin/rails db:encryption:init`, or pin the ones currently in use with `bin/rails shango:encryption:derived_keys`. " \
          "Set #{ALLOW_DERIVED}=true only as a stopgap (the keys then depend on secret_key_base)."
      end
    end
  end
end
