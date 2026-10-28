module Workbench
  class DraftsController < BaseController
    def create
      authorize current_project, :use?
      result = ApiClient::Requests::CreateDraft.call(project: current_project, user: current_user)
      redirect_to workbench_request_path(result.record), status: :see_other
    end
  end
end
