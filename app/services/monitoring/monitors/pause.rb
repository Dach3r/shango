module Monitoring
  module Monitors
    # Stops checking a monitor. Its open incident is resolved as `paused`, without alerting, and its count of failures
    # starts over when it is resumed.
    class Pause
      include Serviceable

      def initialize(monitor:, actor: nil, at: Time.current)
        @monitor = monitor
        @actor = actor
        @at = at
      end

      private

      def perform
        @monitor.with_lock do
          @monitor.incidents.open.find_each { |incident| incident.update!(resolved_at: @at, resolution: "paused") }
          @monitor.update!(enabled: false, failures: 0)
        end
        AuditEvents::Record.call(project: @monitor.project, kind: :monitor_paused, actor: @actor, name: @monitor.name)
        Result.success(@monitor)
      end
    end
  end
end
