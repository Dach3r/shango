module ApiClient
  module Auth
    class JwtBearer < Base
      ALGORITHMS = %w[HS256 HS384 HS512 RS256 RS384 RS512 ES256 ES384 ES512].freeze
      PLACEMENTS = %w[header query].freeze

      field :algorithm, type: :select, options: ALGORITHMS, default: "HS256"
      field :secret, type: :textarea, secret: true, required: true, placeholder: "Shared secret or PEM private key"
      field :payload, type: :textarea, default: "{}", placeholder: '{"sub": "me", "iat": {{$timestamp}}}'
      field :headers, type: :textarea, placeholder: '{"kid": "key-id"}'
      field :add_to, type: :select, options: PLACEMENTS, default: "header"
      field :prefix, default: "Bearer", show_when: { add_to: %w[header] }
      field :query_param, default: "token", show_when: { add_to: %w[query] }

      def apply(request)
        require_config!("secret")
        token = JWT.encode(json("payload"), signing_key, algorithm, json("headers"))

        if config["add_to"] == "query"
          request.add_query(config["query_param"].presence || "token", token)
        else
          request.headers["Authorization"] = [config["prefix"].presence || "Bearer", token].join(" ")
        end
      rescue JWT::EncodeError, OpenSSL::PKey::PKeyError => error
        raise ConfigurationError, "Could not sign JWT: #{error.message}"
      end

      private

      def algorithm
        ALGORITHMS.include?(config["algorithm"]) ? config["algorithm"] : "HS256"
      end

      def signing_key
        case algorithm
        when /\AHS/ then config["secret"]
        when /\ARS/ then OpenSSL::PKey::RSA.new(config["secret"])
        else OpenSSL::PKey::EC.new(config["secret"])
        end
      end

      def json(name)
        raw = config[name].to_s.strip
        return {} if raw.empty?

        parsed = JSON.parse(raw)
        raise ConfigurationError, "JWT #{name} must be a JSON object" unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError
        raise ConfigurationError, "JWT #{name} is not valid JSON"
      end
    end
  end
end
