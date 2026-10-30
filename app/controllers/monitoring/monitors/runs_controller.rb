module Monitoring
  module Monitors
    class RunsController < BaseController
      before_action :find_monitor
      throttle :network, by: -> { current_user.id }

      def create
        authorize @monitor, :run?
        return redirect_to(monitoring_monitor_path(@monitor), alert: t(".paused"), status: :see_other) if @monitor.paused?

        MonitorCheckJob.perform_later(@monitor.id, @monitor.config_version)
        redirect_to monitoring_monitor_path(@monitor), status: :see_other
      end
    end
  end
end
