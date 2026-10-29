module Monitoring
  module Monitors
    class PausesController < BaseController
      before_action :find_monitor

      def create
        authorize @monitor, :pause?
        Monitoring::Monitors::Pause.call(monitor: @monitor, actor: current_user)
        redirect_back_or_to monitoring_monitor_path(@monitor), notice: t(".paused"), status: :see_other
      end

      def destroy
        authorize @monitor, :pause?
        Monitoring::Monitors::Resume.call(monitor: @monitor, actor: current_user)
        redirect_back_or_to monitoring_monitor_path(@monitor), notice: t(".resumed"), status: :see_other
      end
    end
  end
end
