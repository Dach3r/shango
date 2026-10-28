module Workbench
  class DraftsController < BaseController
    def create
      authorize current_project, :use?
      result = ApiClient::Drafts::Create.call(project: current_project, user: current_user)
      redirect_to workbench_request_path(result.record.id), status: :see_other
    end
  end
end
