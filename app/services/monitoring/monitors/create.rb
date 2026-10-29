module Monitoring
  module Monitors
    # Saves a new monitor and checks it right away. Later checks follow the interval, shifted by a random part of a
    # minute so monitors created together do not all run in the same second. `channels` are the ones it alerts.
    class Create
      include Serviceable

      def initialize(monitor:, channels: nil)
        @monitor = monitor
        @channels = channels
      end

      private

      def perform
        @monitor.next_check_at = Schedule.next_after_change(@monitor)
        @monitor.notification_channels = @channels if @channels
        return Result.failure(@monitor, error: :invalid) unless @monitor.save

        AuditEvents::Record.call(project: @monitor.project, kind: :monitor_created, actor: @monitor.creator, name: @monitor.name)
        MonitorCheckJob.perform_later(@monitor.id, @monitor.config_version)
        Result.success(@monitor)
      end
    end
  end
end
