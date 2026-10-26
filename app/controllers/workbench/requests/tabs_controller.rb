module Workbench
  module Requests
    # Closes a request's tab; closing the one being edited moves to the last remaining tab.
    class TabsController < BaseController
      def destroy
        ApiClient::Tabs::Close.call(api_request: @api_request, user: current_user)
        @open_requests = nil
        redirect_to destination, status: :see_other
      end

      private

      def destination
        return workbench_root_path unless params[:current].present?

        remaining = open_requests.last
        remaining ? workbench_request_path(remaining) : workbench_root_path
      end
    end
  end
end
