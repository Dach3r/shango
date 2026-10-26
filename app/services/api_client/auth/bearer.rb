module ApiClient
  module Auth
    class Bearer < Base
      field :token, type: :password, secret: true, required: true
      field :prefix, default: "Bearer"

      def apply(request)
        require_config!("token")
        request.headers["Authorization"] = [config["prefix"].presence || "Bearer", config["token"]].join(" ")
      end
    end
  end
end
