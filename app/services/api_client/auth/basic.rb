module ApiClient
  module Auth
    class Basic < Base
      field :username, required: true
      field :password, type: :password, secret: true

      def apply(request)
        require_config!("username")
        request.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{config["username"]}:#{config["password"]}")}"
      end
    end
  end
end
