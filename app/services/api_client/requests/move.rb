module ApiClient
  module Requests
    # Moves a request into a collection/folder (inside its project) and orders it before `before_id`.
    class Move
      include Serviceable

      def initialize(api_request:, collection_id: nil, folder_id: nil, before_id: nil)
        @api_request = api_request
        @collection_id = collection_id.presence
        @folder_id = folder_id.presence
        @before_id = before_id.presence
      end

      private

      def perform
        collection = @api_request.project.collections.find(@collection_id || @api_request.collection_id)
        @api_request.collection = collection
        @api_request.folder = @folder_id && collection.folders.find(@folder_id)
        return Result.failure(@api_request) unless @api_request.save

        Tree::Reposition.call(record: @api_request, siblings: @api_request.siblings, before_id: @before_id)
        Result.success(@api_request)
      end
    end
  end
end
