module Workbench
  class FoldersController < BaseController
    include DraftPlacement
    include AutomationParameters

    before_action :set_collection, only: %i[new create]
    before_action :set_folder, only: %i[edit update destroy]

    def new
      @folder = @collection.folders.new(parent_id: params[:parent_id])
      authorize @folder
      load_placement
    end

    def create
      authorize @collection.folders.new
      load_placement
      result = ApiClient::Folders::Create.call(collection: @collection, attributes: folder_attributes)
      return redirect_to(after_create_path(result.record), notice: t(".created"), status: :see_other) if result.success?

      @folder = result.record
      render_form_errors
    end

    def edit
    end

    def update
      result = ApiClient::Folders::Update.call(folder: @folder, attributes: folder_attributes)
      return redirect_to(workbench_root_path, notice: t(".updated"), status: :see_other) if result.success?

      render_form_errors
    end

    def destroy
      ApiClient::Folders::Destroy.call(folder: @folder)
      redirect_to workbench_root_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
    end

    def set_folder
      @folder = current_project.folders.find(params[:id])
      @collection = @folder.collection
      authorize @folder
    end

    # Saving a draft goes back to its dialog, inside the folder just created.
    def after_create_path(folder)
      @draft && @placement ? placement_path("folder:#{folder.id}") : workbench_root_path
    end

    def folder_attributes
      params.expect(folder: [:name, :parent_id, :auth_type, { auth_config: {} }, automation_permits])
    end
  end
end
