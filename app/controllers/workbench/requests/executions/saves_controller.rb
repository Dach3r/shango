module Workbench
  module Requests
    module Executions
      class SavesController < Workbench::Requests::BaseController
        # Stores the response of the last run in the request's history.
        def create
          result = ApiClient::Executions::Save.call(api_request: @api_request, user: current_user, id: params[:execution_id])
          return head :gone if result.failure?

          @execution = result.record
        end
      end
    end
  end
end
