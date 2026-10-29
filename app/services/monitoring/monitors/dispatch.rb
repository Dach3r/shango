module Monitoring
  module Monitors
    # Claims the enabled monitors that are due and moves each one interval forward from its planned time (from now when
    # more than one interval was missed, so the schedule neither drifts nor bursts), then enqueues their checks. Claim
    # and enqueue cannot share a transaction (jobs live in the queue database): a crash in between loses one check.
    class Dispatch
      include Serviceable

      BATCH = 500
      SLACK = 5.seconds

      CLAIM = <<~SQL.squish.freeze
        UPDATE uptime_monitors
        SET next_check_at = CASE
          WHEN next_check_at + make_interval(secs => interval) > :now THEN next_check_at + make_interval(secs => interval)
          ELSE CAST(:now AS timestamp) + make_interval(secs => interval)
        END
        WHERE id IN (
          SELECT id FROM uptime_monitors WHERE enabled AND next_check_at <= :due ORDER BY next_check_at LIMIT :batch FOR UPDATE SKIP LOCKED
        )
        RETURNING id, config_version
      SQL

      def initialize(now: Time.current)
        @now = now
      end

      private

      def perform
        rows = UptimeMonitor.connection.select_rows(UptimeMonitor.sanitize_sql_array([CLAIM, { now: @now, due: @now + SLACK, batch: BATCH }]))
        ActiveJob.perform_all_later(rows.map { |id, version| MonitorCheckJob.new(id, version) })
        Result.success(nil, dispatched: rows.size)
      end
    end
  end
end
