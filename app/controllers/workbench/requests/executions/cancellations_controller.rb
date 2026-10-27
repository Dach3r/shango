module Workbench
  module Requests
    module Executions
      # Stops a queued or running send; the worker notices between chunks and redirects.
      class CancellationsController < Workbench::Requests::BaseController
        def create
          state = ApiClient::Executions::RunState.for(params[:execution_id], user_id: current_user.id, api_request_id: @api_request.id)
          return head :not_found unless state

          ApiClient::Executions::RunState.cancel(params[:execution_id])
          head :no_content
        end
      end
    end
  end
end
