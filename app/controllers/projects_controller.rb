class ProjectsController < AuthenticatedController
  layout "devise", only: %i[new create]

  skip_before_action :require_project, only: %i[new create]

  def index
  end

  def new
    @project = Project.new(icon: Project::ICONS.first)
  end

  def create
    @project = Project.create_with_owner(current_user, project_params)

    if @project.persisted?
      redirect_to authenticated_root_path, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.expect(project: %i[name icon])
  end
end
