module Network
  # Saved runs of the project. Each has its own address that shows the tool with the stored result and what was typed.
  class ChecksController < BaseController
    def show
      @check = current_project.network_checks.find(params[:id])
      @kind = @check.kind
      @result = Result.success(nil, **@check.data)
      render "network/workspaces/show"
    end

    def destroy
      check = current_project.network_checks.find(params[:id])
      check.destroy!
      redirect_to network_workspace_path(check.kind), status: :see_other
    end
  end
end
