module Monitoring
  # Uptime of a monitor over a span ending now, from the time its incidents lasted (not from counting results, which
  # push monitors, quick retries and pruning would skew). The span starts no earlier than the monitor's creation; a
  # monitor never checked has no uptime yet.
  module Uptime
    module_function

    def percent(monitor, incidents, span, now: Time.current)
      return if monitor.last_checked_at.nil?

      window = [now - span, monitor.created_at].max..now
      seconds = window.end - window.begin
      return 100.0 unless seconds.positive?

      down = incidents.sum { |incident| incident.seconds_within(window) }
      ((1 - (down / seconds)) * 100).clamp(0, 100).round(2)
    end
  end
end
