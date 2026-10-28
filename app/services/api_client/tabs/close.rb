module ApiClient
  module Tabs
    # Closes the user's tab for a request. A saved request is kept (only its pending edits and unsaved response go); a new draft is discarded.
    class Close
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        if @api_request.persisted?
          RequestTab.where(user: @user, api_request: @api_request).destroy_all
          LatestExecution.where(user: @user, api_request: @api_request).delete_all
        end
        Drafts::Discard.call(api_request: @api_request, user: @user)
        Result.success(@api_request)
      end
    end
  end
end
