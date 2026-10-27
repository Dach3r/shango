module Network
  # Clears the project's history of one tool.
  class HistoriesController < BaseController
    def destroy
      kind = params.expect(:kind)
      return head :unprocessable_content unless NetworkCheck.kinds.key?(kind)

      current_project.network_checks.where(kind:).delete_all
      render turbo_stream: turbo_stream.update("#{kind}_history", partial: "network/checks/list", locals: { kind:, checks: history_for(kind), current: nil })
    end
  end
end
