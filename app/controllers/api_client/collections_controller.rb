module ApiClient
  class CollectionsController < BaseController
    before_action :set_collection, only: %i[edit update destroy]

    def new
      @collection = current_project.collections.new
    end

    def create
      result = Collections::Create.call(project: current_project, attributes: collection_attributes)
      return redirect_to(api_client_root_path, notice: t(".created"), status: :see_other) if result.success?

      @collection = result.record
      render_form_errors
    end

    def edit
    end

    def update
      result = Collections::Update.call(collection: @collection, attributes: collection_attributes)
      return redirect_to(api_client_root_path, notice: t(".updated"), status: :see_other) if result.success?

      render_form_errors
    end

    def destroy
      Collections::Destroy.call(collection: @collection)
      redirect_to api_client_root_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:id])
    end

    def collection_attributes
      params.expect(collection: [:name, :description, :auth_type, { auth_config: {} }])
    end
  end
end
