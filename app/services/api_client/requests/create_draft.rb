module ApiClient
  module Requests
    # Creates a blank request that belongs to the user instead of a collection.
    class CreateDraft
      include Serviceable

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        api_request = @project.api_requests.new(user: @user, name: I18n.t("workbench.requests.draft_name"), auth_type: AuthConfigurable::INHERIT)
        api_request.save!
        Tabs::Open.call(api_request:, user: @user)
        Result.success(api_request)
      end
    end
  end
end
