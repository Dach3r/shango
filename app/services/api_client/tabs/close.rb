module ApiClient
  module Tabs
    # Closes the user's tab for a request; the request itself is kept.
    class Close
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        RequestTab.where(user: @user, api_request: @api_request).destroy_all
        Requests::Stash.clear(api_request: @api_request, user: @user)
        Result.success(@api_request)
      end
    end
  end
end
