module ApiClient
  module Tabs
    # The requests the user has open as tabs, oldest first (no request bodies are loaded; timestamps tell untouched drafts apart).
    class Load
      include Serviceable

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        @project.api_requests.select(*Tree::Load::REQUEST_COLUMNS, :created_at, :updated_at)
                .joins(:request_tabs).where(request_tabs: { user_id: @user.id })
                .order("request_tabs.created_at", "request_tabs.id").to_a
      end
    end
  end
end
