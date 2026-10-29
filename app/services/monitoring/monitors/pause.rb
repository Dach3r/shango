module Monitoring
  module Monitors
    # Stops checking a monitor. Its open incident is resolved as `paused`, without alerting, and its count of failures
    # starts over when it is resumed.
    class Pause
      include Serviceable

      def initialize(monitor:, at: Time.current)
        @monitor = monitor
        @at = at
      end

      private

      def perform
        @monitor.with_lock do
          @monitor.incidents.open.find_each { |incident| incident.update!(resolved_at: @at, resolution: "paused") }
          @monitor.update!(enabled: false, failures: 0)
        end
        Result.success(@monitor)
      end
    end
  end
end
