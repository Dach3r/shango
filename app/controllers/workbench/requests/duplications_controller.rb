module Workbench
  module Requests
    class DuplicationsController < BaseController
      def create
        authorize @api_request, :duplicate?
        result = ApiClient::Requests::Duplicate.call(api_request: @api_request)
        redirect_to workbench_request_path(result.record), status: :see_other
      end
    end
  end
end
