module ApiClient
  module Requests
    # Renders the request, resolved against an environment, as a curl command.
    class ExportCurl
      include Serviceable

      def initialize(api_request:, environment:, user: nil)
        @api_request = api_request
        @environment = environment
        @user = user
      end

      private

      def perform
        built = RequestBuilder.call(api_request: @api_request, environment: @environment, dry_run: true, user: @user)
        return Result.failure(@api_request, error: built.error) if built.failure?

        Result.success(@api_request, curl: Curl::Exporter.call(built: built.record))
      end
    end
  end
end
