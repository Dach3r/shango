module ApiClient
  module Drafts
    # Saves a new draft as a request of a collection (optionally a folder) under `name` when given, last among its siblings; this is the only
    # moment it reaches `api_requests`. The draft goes away; its tab and its latest response now point at the saved request.
    class Commit
      include Serviceable

      def initialize(api_request:, user:, collection:, folder: nil, name: nil)
        @api_request = api_request
        @user = user
        @collection = collection
        @folder = folder
        @name = name
      end

      private

      def perform
        draft = @user.request_drafts.where(api_request_id: nil).find(@api_request.id)
        attributes = draft.data.merge("name" => @name || draft.data["name"].presence || draft.name, "folder_id" => @folder&.id)
        result = Requests::Create.call(collection: @collection, attributes:)
        return result if result.failure?

        ApplicationRecord.transaction do
          RequestTab.where(request_draft: draft).update_all(api_request_id: result.record.id, request_draft_id: nil)
          LatestExecution.where(request_draft: draft).update_all(api_request_id: result.record.id, request_draft_id: nil)
          draft.destroy!
        end
        Result.success(result.record)
      end
    end
  end
end
