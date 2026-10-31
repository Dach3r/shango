module Monitoring
  class BaseController < AuthenticatedController
    include VariableAutocomplete

    helper_method :monitoring_sidebar

    private

    def find_monitor
      @monitor = current_project.uptime_monitors.find(params[:monitor_id] || params[:id])
    end

    def find_channel
      @channel = current_project.notification_channels.find(params[:channel_id] || params[:id])
    end

    # What the sidebar of every Monitoring screen counts: the monitors by status with the overall uptime, and the channels.
    def monitoring_sidebar
      @monitoring_sidebar ||= {
        summary: @overview&.dig(:summary) || Monitoring::Monitors::Overview.call(monitors: current_project.uptime_monitors.strict_loading.to_a).data[:summary],
        channels: current_project.notification_channels.count,
        incidents: open_incident_count
      }
    end
  end
end
