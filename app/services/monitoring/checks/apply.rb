module Monitoring
  module Checks
    # Applies one check to a monitor and fires the events of its state machine (UptimeMonitor's AASM `status`). Every
    # change of state (scheduled checks, Run now, push pings) goes through here,
    # under a row lock, after the probe returned. A result for a disabled monitor, or for a configuration that changed
    # since the check was enqueued (`config_version`), is dropped. Returns the monitor with `transition` (`opened`,
    # `resolved` or nil) and `retry` (a failure below the confirmations, to be checked again soon).
    class Apply
      include Serviceable

      QUICK_RETRY_KINDS = %w[http tcp push].freeze
      DETAIL_LIMIT = 255

      def initialize(monitor_id:, config_version:, outcome:, at: Time.current)
        @monitor_id = monitor_id
        @config_version = config_version
        @outcome = outcome
        @at = at
      end

      private

      def perform
        UptimeMonitor.transaction do
          monitor = UptimeMonitor.lock.find_by(id: @monitor_id)
          return Result.failure(error: :gone) unless monitor
          return Result.failure(error: :stale) if monitor.paused? || monitor.config_version != @config_version

          record(monitor)
          transition, retry_soon = change_state(monitor) unless @outcome.status == "unknown"
          monitor.last_checked_at = @at
          monitor.save!
          Result.success(monitor, transition:, retry: retry_soon || false)
        end
      end

      def record(monitor)
        detail = @outcome.detail&.first(DETAIL_LIMIT)
        monitor.check_results.create!(status: @outcome.status, response_ms: @outcome.response_ms, http_status: @outcome.http_status, error: @outcome.error,
                                      detail:, timings: @outcome.timings, checked_at: @at)
        roll_up(monitor) unless @outcome.status == "unknown"
      end

      def roll_up(monitor)
        ms = @outcome.response_ms
        CheckRollup.upsert(
          { uptime_monitor_id: monitor.id, hour: @at.beginning_of_hour, checks: 1, failures: @outcome.status == "down" ? 1 : 0, responses: ms ? 1 : 0, response_ms_sum: ms.to_i, response_ms_max: ms.to_i },
          unique_by: %i[uptime_monitor_id hour],
          on_duplicate: Arel.sql(<<~SQL.squish)
            checks = check_rollups.checks + 1, failures = check_rollups.failures + EXCLUDED.failures, responses = check_rollups.responses + EXCLUDED.responses,
            response_ms_sum = check_rollups.response_ms_sum + EXCLUDED.response_ms_sum, response_ms_max = GREATEST(check_rollups.response_ms_max, EXCLUDED.response_ms_max)
          SQL
        )
      end

      def change_state(monitor)
        @outcome.status == "up" ? recover(monitor) : fail_once(monitor)
      end

      def recover(monitor)
        monitor.failures = 0
        return [nil, false] if monitor.up?

        transition = (:resolved if monitor.down?)
        monitor.incidents.open.find_each { |incident| incident.update!(resolved_at: @at, resolution: "recovered") }
        monitor.go_up(@at)
        [transition, false]
      end

      def fail_once(monitor)
        monitor.failures += 1
        return [nil, false] if monitor.down?
        return [nil, QUICK_RETRY_KINDS.include?(monitor.kind)] if monitor.failures < monitor.confirmations

        monitor.incidents.create!(project_id: monitor.project_id, cause: @outcome.error, detail: @outcome.detail&.first(DETAIL_LIMIT), started_at: @at)
        monitor.go_down(@at)
        [:opened, false]
      end
    end
  end
end
