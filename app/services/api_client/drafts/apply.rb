module ApiClient
  module Drafts
    # Puts the user's pending edits of a saved request back on it in memory (nothing is saved). Returns whether there were any.
    class Apply
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        draft = @user.request_drafts.find_by(api_request: @api_request)
        return false unless draft

        Requests::Assign.call(api_request: @api_request, attributes: draft.data.except("settings"))
        true
      end
    end
  end
end
