module Workbench
  module Requests
    # Live preview of a `{{response.…}}` reference for the request being edited: `{ status, value }`.
    class ResponseReferencesController < BaseController
      PREVIEW_LIMIT = 500

      def show
        result = ApiClient::ResponseReference.call(api_request: @api_request, user: current_user, name: params[:name])
        render json: result.success? ? { status: "ok", value: result.record.truncate(PREVIEW_LIMIT) } : { status: result.error }
      end
    end
  end
end
