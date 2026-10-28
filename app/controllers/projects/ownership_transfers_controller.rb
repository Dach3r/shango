module Projects
  class OwnershipTransfersController < AuthenticatedController
    def create
      authorize current_project, :manage_members?
      target = current_project.memberships.active.find(params.expect(:member_id))
      result = Members::TransferOwnership.call(from: current_membership, to: target)
      return redirect_to(members_path, notice: t(".transferred", name: target.user.full_name), status: :see_other) if result.success?

      redirect_to members_path, alert: t(".invalid"), status: :see_other
    end
  end
end
