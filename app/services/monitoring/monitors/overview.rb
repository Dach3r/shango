module Monitoring
  module Monitors
    # What the monitor list shows, in three queries for any number of monitors: per monitor the uptime and average
    # response time of the last 24 hours and one slot per hour for its status strip; for the project the counts by
    # status and the overall uptime.
    class Overview
      include Serviceable

      SPAN = 24.hours

      Card = Data.define(:uptime, :average_ms, :hours)

      # One hour of the status strip: `empty` without checks, `up` without failures, `down` when every check failed and
      # `degraded` in between.
      Hour = Data.define(:hour, :checks, :failures) do
        def state
          return :empty if checks.zero?
          return :up if failures.zero?

          failures == checks ? :down : :degraded
        end
      end

      def initialize(monitors:, now: Time.current)
        @monitors = monitors
        @now = now
      end

      # Average response time over hourly rollups, weighted by the checks that got a response.
      def self.average(rollups)
        responses = rollups.sum(&:responses)
        (rollups.sum(&:response_ms_sum).to_f / responses).round if responses.positive?
      end

      private

      def perform
        ids = @monitors.map(&:id)
        rollups = CheckRollup.where(uptime_monitor_id: ids, hour: (@now - SPAN).beginning_of_hour..).order(:hour).group_by(&:uptime_monitor_id)
        incidents = Incident.where(uptime_monitor_id: ids).where("resolved_at IS NULL OR resolved_at > ?", @now - SPAN).group_by(&:uptime_monitor_id)
        cards = @monitors.to_h { |monitor| [monitor.id, card(monitor, rollups.fetch(monitor.id, []), incidents.fetch(monitor.id, []))] }
        Result.success(cards:, summary: summary(cards))
      end

      def card(monitor, rollups, incidents)
        Card.new(uptime: Uptime.percent(monitor, incidents, SPAN, now: @now), average_ms: self.class.average(rollups), hours: hours(rollups))
      end

      # The last 24 hours, oldest first, ending with the current one.
      def hours(rollups)
        by_hour = rollups.index_by(&:hour)
        23.downto(0).map do |ago|
          hour = @now.beginning_of_hour - ago.hours
          rollup = by_hour[hour]
          Hour.new(hour:, checks: rollup&.checks.to_i, failures: rollup&.failures.to_i)
        end
      end

      def summary(cards)
        running = @monitors.select(&:enabled)
        uptimes = running.filter_map { |monitor| cards[monitor.id].uptime }
        {
          total: @monitors.size, limit: UptimeMonitor.per_project_limit, up: running.count(&:up?), down: running.count(&:down?),
          pending: running.count(&:pending?), paused: @monitors.size - running.size, uptime: uptimes.empty? ? nil : (uptimes.sum / uptimes.size).round(2)
        }
      end
    end
  end
end
