module Workbench
  class WorkspacesController < BaseController
    # With tabs open the workbench lands on the last one; the empty state only shows when none is open.
    def show
      last_open = open_requests.last
      return unless last_open

      flash.keep
      redirect_to workbench_request_path(last_open), status: :see_other
    end
  end
end
