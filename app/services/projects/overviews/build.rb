module Projects
  module Overviews
    # What the project's Overview shows to one member: the state of the monitors (narrowed to `environment` when given),
    # the open incidents, what changed in the workspace, the member's own latest runs and a count of what the project holds.
    class Build
      include Serviceable

      LIMIT = 5
      ACTIVITY_LIMIT = 8

      def initialize(project:, user:, environment: nil)
        @project = project
        @user = user
        @environment = environment
      end

      private

      def perform
        monitors = @project.uptime_monitors.in_environment(@environment).order(:name).to_a
        counts = { requests: @project.api_requests.count, monitors: @project.uptime_monitors.count, environments: @project.environments.count }
        Result.success(
          summary: Monitoring::Monitors::Overview.call(monitors:).data[:summary],
          incidents: incidents(monitors),
          activity: @project.audit_events.workspace.recent.includes(:actor).strict_loading.limit(ACTIVITY_LIMIT).to_a,
          runs: runs, counts:, empty: counts.values.all?(&:zero?) && @project.collections.none? && @project.network_checks.none?
        )
      end

      def incidents(monitors)
        @project.incidents.open.where(uptime_monitor_id: monitors.map(&:id)).recent.includes(:uptime_monitor).strict_loading.limit(LIMIT).to_a
      end

      # The member's latest requests sent and network checks, newest first. Both are private to them.
      def runs
        executions = @project.request_executions.where(user: @user).recent.includes(:api_request).strict_loading.limit(LIMIT).to_a
        checks = @project.network_checks.where(user: @user).recent.limit(LIMIT).to_a
        (executions + checks).max_by(LIMIT, &:created_at)
      end
    end
  end
end
