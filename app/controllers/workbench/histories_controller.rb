module Workbench
  class HistoriesController < BaseController
    def show
      @groups = ApiClient::Executions::History.call(project: current_project, user: current_user)
    end
  end
end
