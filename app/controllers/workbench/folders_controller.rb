module Workbench
  class FoldersController < BaseController
    before_action :set_collection, only: %i[new create]
    before_action :set_folder, only: %i[edit update destroy]

    def new
      @folder = @collection.folders.new(parent_id: params[:parent_id])
    end

    def create
      result = ApiClient::Folders::Create.call(collection: @collection, attributes: folder_attributes)
      return redirect_to(workbench_root_path, notice: t(".created"), status: :see_other) if result.success?

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
    end

    def folder_attributes
      params.expect(folder: [:name, :parent_id, :auth_type, { auth_config: {} }])
    end
  end
end
