module Network
  class HistoriesController < BaseController
    def destroy
      kind = params.expect(:kind)
      return head :unprocessable_content unless NetworkCheck.kinds.key?(kind)

      own_checks.where(kind:).delete_all
      redirect_to network_workspace_path(kind), status: :see_other
    end
  end
end
