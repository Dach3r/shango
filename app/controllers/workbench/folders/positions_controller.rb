module Workbench
  module Folders
    class PositionsController < Workbench::BaseController
      def update
        folder = current_project.folders.find(params[:folder_id])
        authorize folder, :update?
        result = ApiClient::Folders::Move.call(folder:, parent_id: params[:parent_id], before_id: params[:before_id])
        result.success? ? head(:no_content) : head(:unprocessable_entity)
      end
    end
  end
end
