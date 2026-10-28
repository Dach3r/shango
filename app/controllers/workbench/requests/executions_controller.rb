module Workbench
  module Requests
    class ExecutionsController < BaseController
      include Workbench::RequestParameters

      throttle :executions, by: -> { current_user.id }, only: :create

      def show
        @execution = @api_request.request_executions.find(params[:id])
      end

      # Sends the request (saving pending edits first when the member may edit it) and streams the response panel back.
      def create
        authorize @api_request, :execute?
        edits = policy(@api_request).update? ? { attributes: request_attributes, uploads: request_uploads, binary_upload: } : { attributes: {}, uploads: {}, binary_upload: nil }
        @uploaded = edits[:uploads].any? || edits[:binary_upload].present?
        result = ApiClient::Requests::Run.call(api_request: @api_request, environment: current_environment, user: current_user, **edits)

        return render_queued(result.data[:run_id]) if result.success? && result.data[:run_id]

        @execution = result.record if result.success?
        @invalid_request = result.record if result.failure?
        render status: result.success? ? :ok : :unprocessable_entity
      end

      private

      # The run continues in a worker; the browser polls the id from this header (see request_form_controller).
      def render_queued(run_id)
        response.headers["X-Execution-Id"] = run_id
        render :running, status: :accepted
      end

      def throttled
        render turbo_stream: turbo_stream.update("response_panel", partial: "workbench/requests/executions/throttled"), status: :too_many_requests
      end
    end
  end
end
