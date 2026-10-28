module Workbench
  module Requests
    # Autosave of the editor: keeps the form as the request's draft (nothing is saved to the request itself) so edits
    # survive switching tabs and reloads. Answers without a body to keep it cheap; destroy discards the pending edits.
    class DraftsController < BaseController
      include Workbench::RequestParameters

      throttle :drafts, by: -> { current_user.id }, only: :update

      def update
        authorize @api_request, :update?
        saved = ApiClient::Drafts::Save.call(api_request: @api_request, user: current_user, attributes: request_attributes)
        head saved.success? ? :no_content : :content_too_large
      end

      def destroy
        authorize @api_request, :update?
        ApiClient::Drafts::Discard.call(api_request: @api_request, user: current_user)
        redirect_to workbench_request_path(@api_request), status: :see_other
      end

      private

      def throttled
        head :too_many_requests
      end
    end
  end
end
