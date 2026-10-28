module Workbench
  module Requests
    # Parent for controllers nested under a request (`/requests/:request_id/...`).
    class BaseController < Workbench::BaseController
      before_action :set_api_request

      private

      def set_api_request
        @api_request = ApiClient::Drafts::Resolve.call(project: current_project, user: current_user, id: params[:request_id])
        authorize @api_request, :show?
      end
    end
  end
end
