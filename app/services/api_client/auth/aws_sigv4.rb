module ApiClient
  module Auth
    class AwsSigv4 < Base
      field :access_key, required: true
      field :secret_key, type: :password, secret: true, required: true
      field :session_token, type: :password, secret: true
      field :region, required: true, placeholder: "us-east-1"
      field :service, required: true, placeholder: "execute-api"

      def apply(request)
        require_config!("access_key", "secret_key", "region", "service")

        signer = Aws::Sigv4::Signer.new(
          service: config["service"], region: config["region"], access_key_id: config["access_key"],
          secret_access_key: config["secret_key"], session_token: config["session_token"].presence
        )
        payload = request.body.is_a?(String) ? request.body : ""
        signature = signer.sign_request(http_method: request.http_method.to_s.upcase, url: request.url, headers: request.headers, body: payload)
        request.headers.merge!(signature.headers)
      end
    end
  end
end
