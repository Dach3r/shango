module ApiClient
  module Tree
    # The user's draft requests for the sidebar (no request bodies are loaded).
    class LoadDrafts
      include Serviceable

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        @project.api_requests.drafts.where(user_id: @user.id).select(*Load::REQUEST_COLUMNS).order(:position, :created_at).to_a
      end
    end
  end
end
