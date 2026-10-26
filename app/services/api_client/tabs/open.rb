module ApiClient
  module Tabs
    # Opens a request as a tab for the user; opening it twice keeps a single tab.
    class Open
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        tab = RequestTab.create_or_find_by!(user: @user, api_request: @api_request)
        Result.success(tab)
      end
    end
  end
end
