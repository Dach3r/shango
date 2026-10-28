module Workbench
  module Requests
    # Drag and drop in the sidebar: moves a request to a collection/folder and orders it.
    class PositionsController < BaseController
      before_action { head :not_found if @api_request.draft? }

      def update
        authorize @api_request, :update?
        authorize current_project.collections.find(params[:collection_id].presence || @api_request.collection_id), :update?
        result = ApiClient::Requests::Move.call(api_request: @api_request, collection_id: params[:collection_id], folder_id: params[:folder_id], before_id: params[:before_id])
        result.success? ? head(:no_content) : head(:unprocessable_entity)
      end
    end
  end
end
