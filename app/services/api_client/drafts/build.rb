module ApiClient
  module Drafts
    # Rebuilds, in memory only, the request a new draft stands for so the editor, runs and tabs treat it like any request.
    class Build
      include Serviceable

      def initialize(draft:)
        @draft = draft
      end

      private

      def perform
        api_request = ApiRequest.new(id: @draft.id, project: @draft.project, name: @draft.name, auth_type: AuthConfigurable::INHERIT,
                                     created_at: @draft.created_at, updated_at: @draft.updated_at)
        api_request.draft_owner_id = @draft.user_id
        Requests::Assign.call(api_request:, attributes: @draft.data)
        api_request.valid?
        api_request
      end
    end
  end
end
