module Workbench
  module Requests
    # The request as a curl command, resolved against the selected environment.
    class CurlExportsController < BaseController
      def show
        result = ApiClient::Requests::ExportCurl.call(api_request: @api_request, environment: current_environment, user: current_user)
        if result.success?
          render json: { curl: result.data[:curl] }
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end
    end
  end
end
