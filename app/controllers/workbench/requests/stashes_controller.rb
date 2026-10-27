module Workbench
  module Requests
    # Keeps the editor's unsaved state (cache only) so switching tabs does not lose it; destroy discards it.
    class StashesController < BaseController
      include Workbench::RequestParameters

      def update
        kept = ApiClient::Requests::Stash.write(api_request: @api_request, user: current_user, attributes: request_attributes)
        head kept ? :no_content : :content_too_large
      end

      def destroy
        ApiClient::Requests::Stash.clear(api_request: @api_request, user: current_user)
        redirect_to workbench_request_path(@api_request), status: :see_other
      end
    end
  end
end
