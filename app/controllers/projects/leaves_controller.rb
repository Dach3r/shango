module Projects
  # A member leaves the project they have selected.
  class LeavesController < AuthenticatedController
    def create
      authorize current_membership, :leave?
      result = Members::Revoke.call(membership: current_membership)
      return redirect_to(root_path, notice: t(".left", project: current_project.name), status: :see_other) if result.success?

      redirect_to members_path, alert: t(".last_owner"), status: :see_other
    end
  end
end
