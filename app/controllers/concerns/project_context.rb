module ProjectContext
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership, :current_project, :current_environment
  end

  private

  def require_project
    redirect_to new_project_path unless current_membership
  end

  # The selected membership if it is still usable, else the oldest one (persisted).
  def current_membership
    return @current_membership if defined?(@current_membership)

    memberships = current_user.available_memberships.includes(:project)
    @current_membership = memberships.find_by(id: current_user.current_membership_id) || memberships.order("memberships.created_at").first
    current_user.update_column(:current_membership_id, @current_membership&.id) if @current_membership&.id != current_user.current_membership_id
    @current_membership
  end

  def current_project
    current_membership&.project
  end

  # The environment this member selected in the current project, if any.
  def current_environment
    return @current_environment if defined?(@current_environment)

    @current_environment = current_membership&.current_environment
  end
end
