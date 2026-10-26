module ApiClient
  module Oauth2
    class ExchangeCode
      include Serviceable

      def initialize(owner:, code:, verifier:, redirect_uri:, environment: nil)
        @owner = owner
        @code = code
        @verifier = verifier
        @redirect_uri = redirect_uri
        @environment = environment
      end

      private

      def perform
        config = VariableResolver.new(@environment&.variable_values || {}).resolve_deep(@owner.auth_config)
        TokenClient.new(config:, owner: @owner).exchange_code(code: @code, verifier: @verifier, redirect_uri: @redirect_uri)
        Result.success(@owner)
      rescue TokenClient::Failed => error
        Result.failure(@owner, error: error.message)
      end
    end
  end
end
