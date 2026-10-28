module Workbench
  module Requests
    # Chooses the collection or folder a new request is saved into; this is where a draft first reaches the database.
    class PlacementsController < BaseController
      before_action :require_draft

      def new
        assign_location
      end

      def update
        authorize @api_request, :update?
        collection, folder = destination
        authorize collection, :update?
        result = ApiClient::Drafts::Commit.call(api_request: @api_request, user: current_user, collection:, folder:, name: params[:request_name].to_s.strip)
        return redirect_to(workbench_request_path(result.record), status: :see_other) if result.success?

        @api_request.errors.merge!(result.record.errors)
        assign_location
        render_form_errors(partial: "form")
      end

      private

      def require_draft
        head :not_found unless @api_request.draft?
      end

      # The name typed so far and the collection or folder being browsed (the collections list when none is given).
      def assign_location
        @request_name = params.fetch(:request_name) { @api_request.name }
        return if params[:destination].blank?

        collection, @folder = destination
        @branch = workspace_tree.find { |item| item.collection.id == collection.id }
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
