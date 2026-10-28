module ApiClient
  module Drafts
    # Throws away the user's draft for a request: pending edits of a saved request, or a new draft with its tab.
    class Discard
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        scope = @user.request_drafts
        scope = @api_request.persisted? ? scope.where(api_request: @api_request) : scope.where(id: @api_request.id, api_request_id: nil)
        scope.destroy_all
        Result.success(@api_request)
      end
    end
  end
end
