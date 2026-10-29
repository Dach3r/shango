module Monitoring
  module Monitors
    # Saves a new monitor and checks it right away. Later checks follow the interval, shifted by a random part of a
    # minute so monitors created together do not all run in the same second.
    class Create
      include Serviceable

      def initialize(monitor:)
        @monitor = monitor
      end

      private

      def perform
        @monitor.next_check_at = Schedule.next_after_change(@monitor)
        return Result.failure(@monitor, error: :invalid) unless @monitor.save

        MonitorCheckJob.perform_later(@monitor.id, @monitor.config_version)
        Result.success(@monitor)
      end
    end
  end
end
