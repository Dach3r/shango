module Workbench
  class CollectionsController < BaseController
    include DraftPlacement

    before_action :set_collection, only: %i[edit update destroy]

    def new
      @collection = current_project.collections.new
      authorize @collection
      load_placement
    end

    def create
      authorize current_project.collections.new
      load_placement
      result = ApiClient::Collections::Create.call(project: current_project, creator: current_user, attributes: collection_attributes)
      return redirect_to(after_create_path(result.record), notice: t(".created"), status: :see_other) if result.success?

      @collection = result.record
      render_form_errors
    end

    def edit
    end

    def update
      result = ApiClient::Collections::Update.call(collection: @collection, attributes: collection_attributes, actor: current_user)
      return redirect_to(workbench_root_path, notice: t(".updated"), status: :see_other) if result.success?

      render_form_errors
    end

    def destroy
      ApiClient::Collections::Destroy.call(collection: @collection, actor: current_user)
      redirect_to workbench_root_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:id])
      authorize @collection
    end

    # A draft that triggered the creation lands in the new collection right away, unless it came from the placement
    # modal, which gets the new collection preselected instead.
    def after_create_path(collection)
      return workbench_root_path unless @draft
      return placement_path("collection:#{collection.id}") if @placement

      saved = ApiClient::Drafts::Commit.call(api_request: @draft, user: current_user, collection:)
      workbench_request_path(saved.success? ? saved.record : @draft)
    end

    def collection_attributes
      params.expect(collection: %i[name description])
    end
  end
end
