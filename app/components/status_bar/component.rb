class StatusBar::Component < ApplicationComponent
  def initialize(user:, project:, projects:, environments: nil, current_environment: nil, open_incidents: 0)
    @user = user
    @project = project
    @projects = projects
    @environments = environments
    @current_environment = current_environment
    @open_incidents = open_incidents
  end
end
