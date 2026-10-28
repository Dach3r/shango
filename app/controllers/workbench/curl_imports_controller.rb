module Workbench
  class CurlImportsController < BaseController
    throttle :imports, by: -> { current_user.id }, only: :create
    before_action :set_collection

    def new
    end

    def create
      result = ApiClient::Requests::ImportCurl.call(collection: @collection, command: params[:command], folder_id: params[:folder_id])
      return redirect_to(workbench_request_path(result.record), status: :see_other) if result.success?

      @error = result.error || result.record.errors.full_messages.to_sentence
      render_form_errors
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
      authorize @collection.api_requests.new, :create?
    end
  end
end
