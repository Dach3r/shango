module Workbench
  # Exports a collection in another API client's format. The file is built by a job (ExportCollectionJob) while the
  # modal polls `show` for the progress; any member of the project may export what they can open.
  class ExportsController < BaseController
    before_action :set_collection, only: %i[new create]

    throttle :exports, by: -> { current_user.id }, only: :create

    def new
    end

    def create
      result = ApiClient::Exports::Enqueue.call(
        collection: @collection, user: current_user, format: params[:format_name], include_environments: flag(:include_environments), include_credentials: flag(:include_credentials)
      )
      if result.failure?
        @error = result.error
        return render(:new, status: :unprocessable_content)
      end

      @export = result.record
    end

    def show
      @export = current_project.collection_exports.where(user: current_user).find(params[:id])
      authorize @export
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
