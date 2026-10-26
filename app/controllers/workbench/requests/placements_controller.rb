module Workbench
  module Requests
    # Chooses the collection or folder a draft request is saved into.
    class PlacementsController < BaseController
      before_action :require_draft

      def new
      end

      def update
        collection, folder = destination
        result = ApiClient::Requests::Place.call(api_request: @api_request, collection:, folder:)
        return redirect_to(workbench_request_path(@api_request), notice: t(".placed", name: collection.name), status: :see_other) if result.success?

        render_form_errors(partial: "form")
      end

      private

      def require_draft
        head :not_found unless @api_request.draft?
      end

      # Params look like "collection:<id>" or "folder:<id>"; both are resolved inside the project.
      def destination
        kind, id = params[:destination].to_s.split(":", 2)
        if kind == "folder"
          folder = current_project.folders.find(id)
          [folder.collection, folder]
        else
          [current_project.collections.find(id), nil]
        end
      end
    end
  end
end
