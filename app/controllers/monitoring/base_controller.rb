module Monitoring
  class BaseController < AuthenticatedController
    include VariableAutocomplete

    private

    def find_monitor
      @monitor = current_project.uptime_monitors.find(params[:monitor_id] || params[:id])
    end

    def find_channel
      @channel = current_project.notification_channels.find(params[:channel_id] || params[:id])
    end
  end
end
