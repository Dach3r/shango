module ApiClient
  module Oauth2
    # Starts the authorization-code (PKCE) flow by redirecting to the provider.
    class AuthorizationsController < ApiClient::BaseController
      def create
        owner = FindOwner.call(project: current_project, type: params[:owner_type], id: params[:owner_id])
        result = Authorize.call(owner:, redirect_uri: api_client_oauth2_callback_url, environment: current_environment)
        return redirect_back_or_to(api_client_root_path, alert: result.error, status: :see_other) if result.failure?

        session[:oauth2] = {
          "state" => result.data[:state], "verifier" => result.data[:verifier], "owner_type" => owner.class.name,
          "owner_id" => owner.id, "return_to" => request.referer.presence || api_client_root_path
        }
        redirect_to result.data[:url], allow_other_host: true
      end
    end
  end
end
