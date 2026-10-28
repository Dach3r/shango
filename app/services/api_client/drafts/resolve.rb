module ApiClient
  module Drafts
    # Finds the request behind an id: a saved request of the project, or the user's new draft rebuilt in memory.
    # Raises ActiveRecord::RecordNotFound for anything else, so other projects' and users' data never resolves.
    class Resolve
      include Serviceable

      def initialize(user:, id:, project: nil)
        @project = project
        @user = user
        @id = id
      end

      private

      def perform
        saved = requests.find_by(id: @id)
        return saved if saved

        Build.call(draft: drafts.where(api_request_id: nil).find(@id))
      end

      def requests
        @project ? @project.api_requests : ApiRequest
      end

      def drafts
        scope = @user.request_drafts
        @project ? scope.where(project: @project) : scope
      end
    end
  end
end
