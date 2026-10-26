module ApiClient
  module Oauth2
    class ClearToken
      include Serviceable

      def initialize(owner:)
        @owner = owner
      end

      private

      def perform
        @owner.update!(auth_config: @owner.auth_config.except(*TokenClient::TOKEN_KEYS))
        Result.success(@owner)
      end
    end
  end
end
