module Monitoring
  module Monitors
    # What the page of one monitor shows: uptime over 24 hours, 7 and 30 days, the average response time and hourly
    # points of the last 24 hours, its incidents (open first) and its latest checks.
    class Report
      include Serviceable

      SPANS = { day: 24.hours, week: 7.days, month: 30.days }.freeze
      INCIDENTS = 20
      CHECKS = 50

      Data = ::Data.define(:uptime, :average_ms, :points, :incidents, :checks)

      def initialize(monitor:, now: Time.current)
        @monitor = monitor
        @now = now
      end

      private

      def perform
        incidents = @monitor.incidents.where("resolved_at IS NULL OR resolved_at > ?", @now - SPANS[:month]).to_a
        rollups = @monitor.check_rollups.where(hour: (@now - SPANS[:day]).beginning_of_hour..).order(:hour).to_a
        Result.success(Data.new(
          uptime: SPANS.transform_values { |span| Uptime.percent(@monitor, incidents, span, now: @now) },
          average_ms: Overview.average(rollups),
          points: rollups.map { |rollup| [rollup.hour, rollup.average_ms] },
          incidents: @monitor.incidents.order(Arel.sql("resolved_at IS NOT NULL"), started_at: :desc).limit(INCIDENTS).to_a,
          checks: @monitor.check_results.recent.limit(CHECKS).to_a
        ))
      end
    end
  end
end
