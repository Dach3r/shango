class Topbar::Component < ApplicationComponent
  def initialize(current_project:, projects:)
    @current_project = current_project
    @projects = projects
  end
end
