module Workbench
  module Requests
    class ExecutionsController < BaseController
      include Workbench::RequestParameters

      throttle :executions, by: -> { current_user.id }, only: :create

      def show
        @execution = @api_request.request_executions.find(params[:id])
      end

      # Sends the request (saving pending edits first) and streams the response panel back.
      def create
        @uploaded = request_uploads.any? || binary_upload.present?
        result = ApiClient::Requests::Run.call(
          api_request: @api_request, environment: current_environment, user: current_user,
          attributes: request_attributes, uploads: request_uploads, binary_upload:
        )

        @execution = result.record if result.success?
        @invalid_request = result.record if result.failure?
        render status: result.success? ? :ok : :unprocessable_entity
      end

      private

      def throttled
        render turbo_stream: turbo_stream.update("response_panel", partial: "workbench/requests/executions/throttled"), status: :too_many_requests
      end
    end
  end
end
