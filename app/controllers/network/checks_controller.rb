module Network
  # Saved runs of the project: opening one shows its stored result and refills the tool's form; deleting removes it.
  class ChecksController < BaseController
    def show
      @check = current_project.network_checks.find(params[:id])
      @result = Result.success(nil, **@check.data)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to network_root_path }
      end
    end

    def destroy
      check = current_project.network_checks.find(params[:id])
      check.destroy!
      render turbo_stream: turbo_stream.update("#{check.kind}_history", partial: "network/checks/list", locals: { kind: check.kind, checks: history_for(check.kind), current: nil })
    end
  end
end
