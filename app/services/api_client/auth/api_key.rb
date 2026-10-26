module ApiClient
  module Auth
    class ApiKey < Base
      PLACEMENTS = %w[header query].freeze

      field :key, required: true, placeholder: "X-API-Key"
      field :value, type: :password, secret: true, required: true
      field :add_to, type: :select, options: PLACEMENTS, default: "header"

      def apply(request)
        require_config!("key", "value")

        if config["add_to"] == "query"
          request.add_query(config["key"], config["value"])
        else
          request.headers[config["key"]] = config["value"]
        end
      end
    end
  end
end
