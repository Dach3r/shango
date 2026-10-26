module ApiClient
  module Auth
    # Lookup of available strategies. Add new ones to STRATEGIES (see Base).
    module Registry
      STRATEGIES = %w[None Basic Bearer ApiKey JwtBearer Digest AwsSigv4 Oauth2].freeze

      module_function

      def all
        STRATEGIES.map { |name| ApiClient::Auth.const_get(name) }
      end

      def keys
        all.map(&:key)
      end

      def fetch(key)
        all.find { |strategy| strategy.key == key.to_s } || raise(ConfigurationError, "Unknown authentication type: #{key}")
      end
    end
  end
end
