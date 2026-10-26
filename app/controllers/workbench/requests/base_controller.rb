module Workbench
  module Requests
    # Parent for controllers nested under a request (`/requests/:request_id/...`).
    class BaseController < Workbench::BaseController
      before_action :set_api_request

      private

      def set_api_request
        @api_request = current_project.api_requests.visible_to(current_user).find(params[:request_id])
      end
    end
  end
end
