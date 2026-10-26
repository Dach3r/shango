module Workbench
  module Requests
    # Asks whether to discard or save a draft when its tab is closed.
    class ClosuresController < BaseController
      before_action :require_draft

      def new
      end

      private

      def require_draft
        head :not_found unless @api_request.draft?
      end
    end
  end
end
