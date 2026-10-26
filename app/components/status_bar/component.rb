class StatusBar::Component < ApplicationComponent
  def initialize(user:, project:, projects:, environments: nil, current_environment: nil)
    @user = user
    @project = project
    @projects = projects
    @environments = environments
    @current_environment = current_environment
  end
end
