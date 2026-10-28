module Workbench
  module Requests
    class DuplicationsController < BaseController
      def create
        authorize @api_request, :duplicate?
        result = if @api_request.draft?
          ApiClient::Drafts::Duplicate.call(api_request: @api_request, user: current_user)
        else
          ApiClient::Requests::Duplicate.call(api_request: @api_request)
        end
        redirect_to workbench_request_path(result.record), status: :see_other
      end
    end
  end
end
