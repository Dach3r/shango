module ApiClient
  module Auth
    # Digest answers the server's 401 challenge, so nothing is sent on the first attempt.
    class Digest < Base
      field :username, required: true
      field :password, type: :password, secret: true

      def apply(_request)
        require_config!("username")
      end

      def respond_to_challenge(response, request)
        challenge = response.headers["www-authenticate"].to_s
        return unless challenge.match?(/\Adigest/i)

        uri = URI.parse(request.url)
        uri.user = CGI.escape(config["username"].to_s)
        uri.password = CGI.escape(config["password"].to_s)
        header = Net::HTTP::DigestAuth.new.auth_header(uri, challenge, request.http_method.to_s.upcase)
        { "Authorization" => header }
      end
    end
  end
end
