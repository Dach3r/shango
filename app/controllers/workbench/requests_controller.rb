module Workbench
  class RequestsController < BaseController
    include RequestParameters

    before_action :set_collection, only: %i[new create]
    before_action :set_api_request, only: %i[show update destroy]

    def show
      @execution = @api_request.request_executions.recent.first
    end

    def new
      @api_request = @collection.api_requests.new(folder_id: params[:folder_id], name: t(".default_name"))
    end

    def create
      result = ApiClient::Requests::Create.call(collection: @collection, attributes: request_attributes)
      return redirect_to(workbench_request_path(result.record), notice: t(".created"), status: :see_other) if result.success?

      @api_request = result.record
      render_form_errors
    end

    def update
      result = ApiClient::Requests::Update.call(api_request: @api_request, attributes: request_attributes, uploads: request_uploads, binary_upload:)
      return redirect_to(workbench_request_path(@api_request), notice: t(".updated"), status: :see_other) if result.success?

      @execution = @api_request.request_executions.recent.first
      render :show, status: :unprocessable_entity
    end

    def destroy
      ApiClient::Requests::Destroy.call(api_request: @api_request)
      redirect_to workbench_root_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
    end

    def set_api_request
      @api_request = current_project.api_requests.find(params[:id])
    end
  end
end
