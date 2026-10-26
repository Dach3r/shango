module ApiClient
  module Oauth2
    # "Get new access token" for client_credentials / password grants.
    class RequestToken
      include Serviceable

      def initialize(owner:, environment: nil)
        @owner = owner
        @environment = environment
      end

      private

      def perform
        config = resolver.resolve_deep(@owner.auth_config)
        raise TokenClient::Failed, I18n.t("api_client.oauth2.unsupported_grant") if config["grant_type"] == "authorization_code"

        TokenClient.new(config:, owner: @owner).fetch
        Result.success(@owner)
      rescue TokenClient::Failed => error
        Result.failure(@owner, error: error.message)
      end

      def resolver
        VariableResolver.new(@environment&.variable_values || {})
      end
    end
  end
end
