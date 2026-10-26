module Workbench
  module Oauth2
    # Starts the authorization-code (PKCE) flow by redirecting to the provider.
    class AuthorizationsController < Workbench::BaseController
      def create
        owner = ApiClient::Oauth2::FindOwner.call(project: current_project, user: current_user, type: params[:owner_type], id: params[:owner_id])
        result = ApiClient::Oauth2::Authorize.call(owner:, redirect_uri: workbench_oauth2_callback_url, environment: current_environment)
        return redirect_back_or_to(workbench_root_path, alert: result.error, status: :see_other) if result.failure?

        session[:oauth2] = {
          "state" => result.data[:state], "verifier" => result.data[:verifier], "owner_type" => owner.class.name,
          "owner_id" => owner.id, "return_to" => request.referer.presence || workbench_root_path
        }
        redirect_to result.data[:url], allow_other_host: true
      end
    end
  end
end
