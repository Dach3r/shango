module ApiClient
  module Oauth2
    # "Get new access token" for client credentials / password grants, and clearing a stored token.
    class TokensController < ApiClient::BaseController
      before_action :set_owner

      def create
        result = RequestToken.call(owner: @owner, environment: current_environment)
        flash[result.success? ? :notice : :alert] = result.success? ? t(".fetched") : t(".failed", error: result.error)
        redirect_back_or_to api_client_root_path, status: :see_other
      end

      def destroy
        ClearToken.call(owner: @owner)
        redirect_back_or_to api_client_root_path, notice: t(".cleared"), status: :see_other
      end

      private

      def set_owner
        @owner = FindOwner.call(project: current_project, type: params[:owner_type], id: params[:owner_id])
      end
    end
  end
end
