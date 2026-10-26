module ApiClient
  module Tabs
    # The requests the user has open as tabs, oldest first (no request bodies are loaded).
    class Load
      include Serviceable

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        @project.api_requests.select(*Tree::Load::REQUEST_COLUMNS)
                .joins(:request_tabs).where(request_tabs: { user_id: @user.id })
                .order("request_tabs.created_at", "request_tabs.id").to_a
      end
    end
  end
end
