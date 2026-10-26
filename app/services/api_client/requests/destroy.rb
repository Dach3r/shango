module ApiClient
  module Requests
    class Destroy
      include Serviceable

      def initialize(api_request:)
        @api_request = api_request
      end

      private

      def perform
        @api_request.destroy ? Result.success(@api_request) : Result.failure(@api_request)
      end
    end
  end
end
