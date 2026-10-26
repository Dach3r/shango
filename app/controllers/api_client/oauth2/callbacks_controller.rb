module ApiClient
  module Oauth2
    # Receives the provider redirect and trades the code for tokens.
    class CallbacksController < ApiClient::BaseController
      def show
        flow = session.delete(:oauth2).to_h
        return redirect_to(api_client_root_path, alert: t(".invalid_state")) unless valid_state?(flow)

        owner = FindOwner.call(project: current_project, type: flow["owner_type"], id: flow["owner_id"])
        result = ExchangeCode.call(owner:, code: params[:code], verifier: flow["verifier"], redirect_uri: api_client_oauth2_callback_url, environment: current_environment)
        flash[result.success? ? :notice : :alert] = result.success? ? t(".fetched") : t(".failed", error: result.error)
        redirect_to flow["return_to"].presence || api_client_root_path
      end

      private

      def valid_state?(flow)
        flow["state"].present? && params[:code].present? && ActiveSupport::SecurityUtils.secure_compare(flow["state"], params[:state].to_s)
      end
    end
  end
end
