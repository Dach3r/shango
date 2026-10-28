module Projects
  class CurrentEnvironmentsController < AuthenticatedController
    def update
      authorize current_project, :use?
      Environments::Select.call(membership: current_membership, environment_id: params[:environment_id])
      redirect_back_or_to root_path, status: :see_other
    end
  end
end
