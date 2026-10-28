module ApiClient
  module Requests
    # Persists only the settings of a request, leaving every other (possibly unsaved) edit alone.
    class UpdateSettings
      include Serviceable

      def initialize(api_request:, settings:)
        @api_request = api_request
        @settings = settings.to_h
      end

      private

      def perform
        @api_request.settings = @api_request.settings.merge(@settings)
        @api_request.save ? Result.success(@api_request) : Result.failure(@api_request)
      end
    end
  end
end
