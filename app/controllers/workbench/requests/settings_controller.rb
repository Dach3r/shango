module Workbench
  module Requests
    # Saves the request settings as they change; unlike the other edits they do not wait for the save button.
    class SettingsController < BaseController
      def update
        authorize @api_request, :update?
        settings = params.fetch(:api_request, {}).permit(settings: %i[timeout follow_redirects max_redirects verify_ssl use_cookie_jar])[:settings]
        result = if @api_request.draft?
          ApiClient::Drafts::Settings.call(api_request: @api_request, user: current_user, settings:)
        else
          ApiClient::Requests::UpdateSettings.call(api_request: @api_request, settings:)
        end
        head result.success? ? :no_content : :unprocessable_entity
      end
    end
  end
end
