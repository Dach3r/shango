class ProjectsController < AuthenticatedController
  layout "devise", only: %i[new create]

  skip_before_action :require_project, only: %i[new create]

  def new
    @project = Project.new(icon: "rocket")
  end

  def create
    @project = Project.create_with_owner(current_user, project_params)

    if @project.persisted?
      current_user.update!(current_membership_id: current_user.memberships.active.find_by!(project: @project).id)
      redirect_to root_path, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.expect(project: %i[name icon])
  end
end
