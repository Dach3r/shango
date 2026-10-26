module ApiClient
  module Auth
    # OAuth 2.0 bearer tokens. Tokens are fetched through ApiClient::Oauth2 services and stored,
    # encrypted, in the owner's auth config next to these form fields.
    class Oauth2 < Base
      GRANT_TYPES = %w[client_credentials password authorization_code].freeze
      PLACEMENTS = %w[header query].freeze
      CLIENT_AUTHENTICATIONS = %w[basic_header body].freeze
      EXPIRY_LEEWAY = 30.seconds

      field :grant_type, type: :select, options: GRANT_TYPES, default: "client_credentials"
      field :token_url, required: true, placeholder: "https://auth.example.com/oauth/token"
      field :authorization_url, placeholder: "https://auth.example.com/authorize", show_when: { grant_type: %w[authorization_code] }
      field :client_id, required: true
      field :client_secret, type: :password, secret: true
      field :username, show_when: { grant_type: %w[password] }
      field :password, type: :password, secret: true, show_when: { grant_type: %w[password] }
      field :scope, placeholder: "read write"
      field :audience
      field :client_authentication, type: :select, options: CLIENT_AUTHENTICATIONS, default: "basic_header"
      field :add_to, type: :select, options: PLACEMENTS, default: "header"
      field :prefix, default: "Bearer", show_when: { add_to: %w[header] }
      field :query_param, default: "access_token", show_when: { add_to: %w[query] }

      MANAGED_KEYS = %w[access_token refresh_token expires_at token_type].freeze

      def self.managed_keys
        MANAGED_KEYS
      end

      def apply(request)
        refresh_token_if_needed
        token = config["access_token"]
        raise ConfigurationError, "No access token yet. Use “Get new access token” first." if token.blank?

        if config["add_to"] == "query"
          request.add_query(config["query_param"].presence || "access_token", token)
        else
          request.headers["Authorization"] = [config["prefix"].presence || config["token_type"].presence || "Bearer", token].join(" ")
        end
      end

      private

      def managed_secrets
        [config["access_token"], config["refresh_token"]].compact_blank
      end

      def expired?
        expires_at = config["expires_at"].presence
        return false unless expires_at

        Time.zone.parse(expires_at.to_s) <= Time.current + EXPIRY_LEEWAY
      end

      def refresh_token_if_needed
        return if dry_run? || owner.nil? || config["access_token"].present? && !expired?
        return unless config["refresh_token"].present? || %w[client_credentials password].include?(config["grant_type"])

        tokens = ApiClient::Oauth2::TokenClient.new(config:, owner:).refresh_or_fetch
        config.merge!(tokens)
      rescue ApiClient::Oauth2::TokenClient::Failed => error
        raise ConfigurationError, error.message
      end
    end
  end
end
