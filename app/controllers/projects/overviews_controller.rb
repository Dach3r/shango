module Projects
  # The project's front page: monitors, incidents, recent activity and the member's own latest runs in one place.
  class OverviewsController < AuthenticatedController
    include EnvironmentScope

    def show
      authorize current_project, :use?
      @overview = Projects::Overviews::Build.call(project: current_project, user: current_user, environment: scope_environment).data
    end
  end
end
