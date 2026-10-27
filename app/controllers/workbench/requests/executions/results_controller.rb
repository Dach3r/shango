module Workbench
  module Requests
    module Executions
      # Polled by the browser while a queued run executes: 202 while running, the response panel once done.
      class ResultsController < Workbench::Requests::BaseController
        def show
          state = ApiClient::Executions::RunState.for(params[:execution_id], user_id: current_user.id, api_request_id: @api_request.id)
          return head :not_found unless state

          case state["state"]
          when "running" then head :accepted
          when "done" then render_result(state)
          when "cancelled" then head :no_content
          else head :unprocessable_content
          end
        end

        private

        def render_result(state)
          @execution = RequestExecution.pending(params[:execution_id])
          return head :gone unless @execution

          @uploaded = state["uploaded"]
          render "workbench/requests/executions/create", formats: :turbo_stream
        end
      end
    end
  end
end
