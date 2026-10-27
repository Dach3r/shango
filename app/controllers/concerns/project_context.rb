module ProjectContext
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership, :current_project, :current_environment, :available_projects, :project_environments
  end

  private

  def require_project
    redirect_to new_project_path unless current_membership
  end

  # The selected membership if it is still usable, else the oldest one (persisted).
  def current_membership
    return @current_membership if defined?(@current_membership)

    @current_membership = usable_memberships.find { |membership| membership.id == current_user.current_membership_id } || usable_memberships.min_by(&:created_at)
    current_user.update_column(:current_membership_id, @current_membership&.id) if @current_membership&.id != current_user.current_membership_id
    @current_membership
  end

  def current_project
    current_membership&.project
  end

  # The environment this member selected in the current project, if any.
  def current_environment
    return @current_environment if defined?(@current_environment)

    @current_environment = project_environments.find { |environment| environment.id == current_membership.current_environment_id }
  end

  # Projects the user can switch to, by name.
  def available_projects
    usable_memberships.map(&:project)
  end

  def project_environments
    @project_environments ||= current_project ? current_project.environments.ordered.to_a : []
  end

  # Every active membership with its project, in one query.
  def usable_memberships
    @usable_memberships ||= current_user.available_memberships.includes(:project).merge(Project.order(:name)).to_a
  end
end
