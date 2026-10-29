module Monitoring
  module Probes
    # Push monitor: nothing is sent. Down (`no_ping`) once no ping came within interval plus grace of the last one, or
    # of when the monitor was created, resumed or last changed state; nil (nothing to apply) while it is on time. Pings
    # themselves are applied by Monitors::Ping.
    module Push
      module_function

      def call(monitor, now: Time.current)
        since = [monitor.last_pinged_at, monitor.last_status_change_at, monitor.created_at].compact.max
        return if monitor.push_deadline(since) > now

        Checks::Outcome.down(:no_ping, detail: monitor.last_pinged_at&.utc&.iso8601)
      end
    end
  end
end
