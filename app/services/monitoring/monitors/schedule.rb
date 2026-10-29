module Monitoring
  module Monitors
    module Schedule
      SPREAD = 60

      module_function

      # The next planned check after one that runs now: one interval later plus a random part of a minute. A push
      # monitor is checked when it turns overdue: interval plus grace after its last ping (or after now).
      def next_after_change(monitor, now: Time.current)
        return monitor.push_deadline([monitor.last_pinged_at, now].compact.max) if monitor.push?

        now + monitor.interval.to_i.seconds + SecureRandom.random_number(SPREAD).seconds
      end
    end
  end
end
