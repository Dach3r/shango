module ApiClient
  module Oauth2
    # Talks to an OAuth 2.0 token endpoint and stores the resulting tokens (encrypted) on the owner.
    # `config` has its variables already resolved; `owner` is the collection/folder/request holding the settings.
    class TokenClient
      class Failed < StandardError; end

      TOKEN_KEYS = ApiClient::Auth::Oauth2.managed_keys.freeze
      TIMEOUT = 30

      def initialize(config:, owner:)
        @config = config.to_h.stringify_keys
        @owner = owner
      end

      def refresh_or_fetch
        return refresh if @config["refresh_token"].present?

        fetch
      end

      # client_credentials and password grants.
      def fetch
        params = { "grant_type" => @config["grant_type"], "scope" => @config["scope"].presence, "audience" => @config["audience"].presence }
        params.merge!("username" => @config["username"], "password" => @config["password"]) if @config["grant_type"] == "password"
        store(request_token(params))
      end

      def refresh
        store(request_token("grant_type" => "refresh_token", "refresh_token" => @config["refresh_token"], "scope" => @config["scope"].presence))
      rescue Failed
        raise unless %w[client_credentials password].include?(@config["grant_type"])

        fetch
      end

      def exchange_code(code:, verifier:, redirect_uri:)
        store(request_token("grant_type" => "authorization_code", "code" => code, "redirect_uri" => redirect_uri, "code_verifier" => verifier))
      end

      private

      def request_token(params)
        raise Failed, I18n.t("api_client.oauth2.missing_token_url") if @config["token_url"].blank?

        params = params.compact_blank
        headers = { "Accept" => "application/json", "Content-Type" => "application/x-www-form-urlencoded", "User-Agent" => "Shango/1.0" }
        if @config["client_authentication"] == "body"
          params.merge!("client_id" => @config["client_id"], "client_secret" => @config["client_secret"].presence).compact_blank!
        else
          headers["Authorization"] = "Basic #{Base64.strict_encode64("#{@config["client_id"]}:#{@config["client_secret"]}")}"
        end

        response = ApiClient::Connection.build(url: @config["token_url"], timeout: TIMEOUT).post(@config["token_url"], URI.encode_www_form(params), headers)
        parse(response)
      rescue ApiClient::Connection::InvalidUrl, ApiClient::SsrfPolicy::Blocked, Faraday::Error, SocketError => error
        raise Failed, error.message
      end

      def parse(response)
        body = JSON.parse(response.body.to_s)
        return body if response.success? && body["access_token"].present?

        raise Failed, [body["error"], body["error_description"]].compact.join(": ").presence || "HTTP #{response.status}"
      rescue JSON::ParserError
        raise Failed, "HTTP #{response.status}: #{I18n.t("api_client.oauth2.invalid_response")}"
      end

      def store(body)
        tokens = {
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"].presence || @config["refresh_token"],
          "token_type" => body["token_type"],
          "expires_at" => (body["expires_in"].present? ? Time.current + body["expires_in"].to_i : nil)&.iso8601
        }.compact

        @owner.update!(auth_config: @owner.auth_config.except(*TOKEN_KEYS).merge(tokens))
        tokens
      end
    end
  end
end
