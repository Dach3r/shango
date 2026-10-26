module ApiClient
  module Requests
    class DuplicationsController < BaseController
      def create
        result = Duplicate.call(api_request: @api_request)
        redirect_to api_client_request_path(result.record), notice: t(".duplicated"), status: :see_other
      end
    end
  end
end
