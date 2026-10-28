module ApiClient
  module Drafts
    # Opens a blank request as a draft tab. Nothing is written to `api_requests` until the draft is saved.
    class Create
      include Serviceable

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        draft = @project.request_drafts.new(user: @user, name: I18n.t("workbench.requests.draft_name"))
        draft.data = {}
        draft.save!
        RequestTab.create!(user: @user, request_draft: draft)
        Result.success(draft)
      end
    end
  end
end
