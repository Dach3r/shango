module Workbench
  module Runs
    class CancellationsController < Workbench::BaseController
      def create
        run = current_project.collection_runs.find(params[:run_id])
        authorize run, :cancel?
        ApiClient::Runs::Cancel.call(run:)
        redirect_to workbench_run_path(run), status: :see_other
      end
    end
  end
end
