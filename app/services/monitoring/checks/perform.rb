module Monitoring
  module Checks
    # One scheduled or manual check: skips a monitor that is gone, paused or edited since the check was enqueued
    # before probing, then probes and applies the outcome. A probe with nothing to say (a push monitor still on time)
    # changes nothing.
    class Perform
      include Serviceable

      def initialize(monitor_id:, config_version:)
        @monitor_id = monitor_id
        @config_version = config_version
      end

      private

      def perform
        monitor = UptimeMonitor.find_by(id: @monitor_id)
        return Result.failure(error: :gone) unless monitor
        return Result.failure(error: :stale) if monitor.paused? || monitor.config_version != @config_version

        outcome = Run.call(monitor)
        return Result.success(monitor, transition: nil, retry: false) unless outcome

        Apply.call(monitor_id: monitor.id, config_version: @config_version, outcome:)
      end
    end
  end
end
