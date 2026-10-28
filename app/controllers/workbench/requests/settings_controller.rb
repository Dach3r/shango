module Workbench
  module Requests
    # Saves the request settings as they change; unlike the other edits they do not wait for the save button.
    class SettingsController < BaseController
      def update
        result = ApiClient::Requests::UpdateSettings.call(api_request: @api_request, settings: params.fetch(:api_request, {}).permit(settings: %i[timeout follow_redirects max_redirects verify_ssl use_cookie_jar])[:settings])
        head result.success? ? :no_content : :unprocessable_entity
      end
    end
  end
end
