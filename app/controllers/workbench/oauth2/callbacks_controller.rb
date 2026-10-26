module Workbench
  module Oauth2
    # Receives the provider redirect and trades the code for tokens.
    class CallbacksController < Workbench::BaseController
      def show
        flow = session.delete(:oauth2).to_h
        return redirect_to(workbench_root_path, alert: t(".invalid_state")) unless valid_state?(flow)

        owner = ApiClient::Oauth2::FindOwner.call(project: current_project, user: current_user, type: flow["owner_type"], id: flow["owner_id"])
        result = ApiClient::Oauth2::ExchangeCode.call(owner:, code: params[:code], verifier: flow["verifier"], redirect_uri: workbench_oauth2_callback_url, environment: current_environment)
        flash[result.success? ? :notice : :alert] = result.success? ? t(".fetched") : t(".failed", error: result.error)
        redirect_to flow["return_to"].presence || workbench_root_path
      end

      private

      def valid_state?(flow)
        flow["state"].present? && params[:code].present? && ActiveSupport::SecurityUtils.secure_compare(flow["state"], params[:state].to_s)
      end
    end
  end
end
