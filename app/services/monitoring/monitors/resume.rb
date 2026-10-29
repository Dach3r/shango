module Monitoring
  module Monitors
    # Checks a paused monitor again from scratch: status `pending`, checked on the next dispatch.
    class Resume
      include Serviceable

      def initialize(monitor:, at: Time.current)
        @monitor = monitor
        @at = at
      end

      private

      def perform
        @monitor.with_lock do
          @monitor.restart(@at)
          @monitor.update!(enabled: true, failures: 0, next_check_at: @at)
        end
        Result.success(@monitor)
      end
    end
  end
end
