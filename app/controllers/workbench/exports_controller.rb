module Workbench
  # Downloads a collection in another API client's format. Any member of the project may export what they can open.
  class ExportsController < BaseController
    before_action :set_collection

    throttle :exports, by: -> { current_user.id }, only: :create

    def new
    end

    def create
      result = ApiClient::Exports::Export.call(
        collection: @collection, format: params[:format_name], include_environments: flag(:include_environments), include_credentials: flag(:include_credentials)
      )
      return redirect_to(workbench_root_path, alert: result.error, status: :see_other) if result.failure?

      send_data result.data[:content], filename: result.data[:filename], type: result.data[:content_type], disposition: "attachment"
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
      authorize @collection, :export?
    end

    def flag(name)
      ActiveModel::Type::Boolean.new.cast(params[name]) == true
    end
  end
end
