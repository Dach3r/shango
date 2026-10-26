class AuthenticatedController < ApplicationController
  before_action :authenticate_user!
  before_action :require_project

  private

  def require_project
    redirect_to new_project_path unless current_user.projects.active.exists?
  end
end
