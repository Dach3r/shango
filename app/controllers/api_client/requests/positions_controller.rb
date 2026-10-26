module ApiClient
  module Requests
    # Drag and drop in the sidebar: moves a request to a collection/folder and orders it.
    class PositionsController < BaseController
      def update
        result = Move.call(api_request: @api_request, collection_id: params[:collection_id], folder_id: params[:folder_id], before_id: params[:before_id])
        result.success? ? head(:no_content) : head(:unprocessable_entity)
      end
    end
  end
end
