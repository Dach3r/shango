module Monitoring
  module Monitors
    # A ping of a push monitor, found by its secret token: an `up` check through Checks::Apply, and the next check
    # planned for when it would turn overdue. A ping to a paused monitor is accepted and ignored.
    class Ping
      include Serviceable

      def initialize(token:, at: Time.current)
        @token = token
        @at = at
      end

      private

      def perform
        monitor = UptimeMonitor.find_by_push_token(@token)
        return Result.failure(error: :not_found) unless monitor&.push?
        return Result.success(monitor, ignored: true) if monitor.paused?

        result = Checks::Apply.call(monitor_id: monitor.id, config_version: monitor.config_version, outcome: Checks::Outcome.up, at: @at)
        monitor.update_columns(last_pinged_at: @at, next_check_at: monitor.push_deadline(@at)) if result.success?
        Result.success(monitor)
      end
    end
  end
end
