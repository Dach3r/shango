module Monitoring
  module Monitors
    module Schedule
      SPREAD = 60

      module_function

      # The next planned check after one that runs now: one interval later plus a random part of a minute.
      def next_after_change(monitor, now: Time.current)
        now + monitor.interval.to_i.seconds + SecureRandom.random_number(SPREAD).seconds
      end
    end
  end
end
