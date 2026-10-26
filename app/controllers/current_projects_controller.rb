class CurrentProjectsController < AuthenticatedController
  def update
    membership = current_user.available_memberships.find_by!(project_id: params.expect(:project_id))
    current_user.update!(current_membership_id: membership.id)

    redirect_to root_path, status: :see_other
  end
end
