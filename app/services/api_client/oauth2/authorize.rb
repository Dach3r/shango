module ApiClient
  module Oauth2
    # Builds the authorization-code (PKCE) redirect. Result#data: url, state, verifier.
    class Authorize
      include Serviceable

      def initialize(owner:, redirect_uri:, environment: nil)
        @owner = owner
        @redirect_uri = redirect_uri
        @environment = environment
      end

      private

      def perform
        config = VariableResolver.new(@environment&.variable_values || {}).resolve_deep(@owner.auth_config)
        return Result.failure(@owner, error: I18n.t("workbench.oauth2.missing_authorization_url")) if config["authorization_url"].blank?

        verifier = SecureRandom.urlsafe_base64(48)
        state = SecureRandom.urlsafe_base64(24)
        params = {
          "response_type" => "code", "client_id" => config["client_id"], "redirect_uri" => @redirect_uri, "state" => state,
          "scope" => config["scope"].presence, "audience" => config["audience"].presence,
          "code_challenge" => Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false), "code_challenge_method" => "S256"
        }.compact_blank

        separator = config["authorization_url"].include?("?") ? "&" : "?"
        Result.success(@owner, url: "#{config["authorization_url"]}#{separator}#{URI.encode_www_form(params)}", state:, verifier:)
      end
    end
  end
end
