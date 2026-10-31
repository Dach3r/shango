module Workbench
  # Runs a collection (or one folder) request by request. A job sends them (RunCollectionJob) while `show` refreshes itself;
  # any member can run what they can open, and a member's runs go one at a time.
  class RunsController < BaseController
    before_action :set_collection, only: %i[index new create]
    before_action :set_folder, only: %i[new create]

    throttle :runs, by: -> { current_user.id }, only: :create

    def index
      authorize @collection, :show?
      @runs = current_project.collection_runs.where(collection: @collection).includes(:folder, :environment, :user).recent.limit(CollectionRun::KEEP_PER_COLLECTION)
    end

    def new
      authorize new_run, :create?
      load_form
    end

    def create
      authorize new_run, :create?
      result = ApiClient::Runs::Create.call(collection: @collection, folder: @folder, user: current_user, environment: selected_environment, options: run_options)
      return redirect_to(workbench_run_path(result.record), status: :see_other) if result.success?

      @error = result.error
      @max = result.data[:max]
      load_form
      render :new, status: :unprocessable_content
    end

    def show
      @run = current_project.collection_runs.includes(:collection, :folder, :environment, :user).find(params[:id])
      authorize @run
      respond_to do |format|
        format.html
        format.json { send_report(:json, "application/json") }
        format.xml { send_report(:junit, "application/xml") }
      end
    end

    private

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
    end

    def set_folder
      @folder = @collection.folders.find(params[:folder_id]) if params[:folder_id].present?
    end

    def new_run
      CollectionRun.new(project: current_project, collection: @collection, user: current_user)
    end

    def load_form
      @environments = current_project.environments.ordered
      @selected_environment = selected_environment || current_environment
      @count = ApiClient::Runs::Scope.call(collection: @collection, folder: @folder).record.size
    end

    def selected_environment
      current_project.environments.find_by(id: params[:environment_id])
    end

    def run_options
      params.permit(:stop_on_failure, :persist_variables, :delay_ms).to_h
    end

    def send_report(format, type)
      report = ApiClient::Runs::Report.call(run: @run, format:).record
      send_data report, type:, filename: "#{@run.scope_name.parameterize.presence || "run"}-#{@run.created_at.strftime("%Y%m%d-%H%M%S")}.#{format == :junit ? "xml" : "json"}", disposition: "attachment"
    end
  end
end
