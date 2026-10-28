module Workbench
  class CollectionsController < BaseController
    before_action :set_collection, only: %i[edit update destroy]

    def new
      @collection = current_project.collections.new
    end

    def create
      @draft = draft_to_place
      result = ApiClient::Collections::Create.call(project: current_project, creator: current_user, attributes: collection_attributes)
      return redirect_to(after_create_path(result.record), notice: t(".created"), status: :see_other) if result.success?

      @collection = result.record
      render_form_errors
    end

    def edit
    end

    def update
      result = ApiClient::Collections::Update.call(collection: @collection, attributes: collection_attributes)
      return redirect_to(workbench_root_path, notice: t(".updated"), status: :see_other) if result.success?

      render_form_errors
    end

    def destroy
      ApiClient::Collections::Destroy.call(collection: @collection)
      redirect_to workbench_root_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:id])
    end

    def draft_to_place
      return if params[:draft_id].blank?

      current_project.api_requests.drafts.visible_to(current_user).find(params[:draft_id])
    end

    # A draft that triggered the creation lands in the new collection right away.
    def after_create_path(collection)
      return workbench_root_path unless @draft

      ApiClient::Requests::Place.call(api_request: @draft, collection:)
      workbench_request_path(@draft)
    end

    def collection_attributes
      params.expect(collection: %i[name description])
    end
  end
end
