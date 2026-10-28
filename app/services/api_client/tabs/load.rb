module ApiClient
  module Tabs
    # What the user has open as tabs, oldest first: saved requests and new drafts (the latter as in-memory requests with
    # just what a tab shows, since their payload is encrypted and never loaded here; timestamps tell untouched ones apart).
    # Owner and collection come along so the tabs can tell what the member may do with each request.
    class Load
      include Serviceable

      TAB_COLUMNS = ["request_tabs.created_at AS tab_created_at", "request_tabs.id AS tab_id"].freeze

      Entry = Struct.new(:request, :tab_created_at, :tab_id)

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        (saved + drafts).sort_by { |entry| [entry.tab_created_at, entry.tab_id] }.map(&:request)
      end

      def saved
        @project.api_requests.select(*Tree::Load::REQUEST_COLUMNS, :updated_at, *TAB_COLUMNS)
                .preload(:collection).joins(:request_tabs).where(request_tabs: { user_id: @user.id })
                .map { |request| Entry.new(request, request.tab_created_at, request.tab_id) }
      end

      def drafts
        @project.request_drafts.select(:id, :name, :http_method, :created_at, :updated_at, *TAB_COLUMNS)
                .joins(:request_tabs).where(request_tabs: { user_id: @user.id })
                .map { |draft| Entry.new(shell(draft), draft.tab_created_at, draft.tab_id) }
      end

      def shell(draft)
        ApiRequest.new(id: draft.id, project: @project, name: draft.name, http_method: draft.http_method, created_at: draft.created_at, updated_at: draft.updated_at).tap do |request|
          request.draft_owner_id = @user.id
        end
      end
    end
  end
end
