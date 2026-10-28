module ApiClient
  module Tabs
    # Opens a request (saved, or a new draft) as a tab for the user; opening it twice keeps a single tab.
    class Open
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        tab = if @api_request.persisted?
          RequestTab.create_or_find_by!(user: @user, api_request: @api_request)
        else
          RequestTab.create_or_find_by!(user: @user, request_draft_id: @api_request.id)
        end
        Result.success(tab)
      end
    end
  end
end
