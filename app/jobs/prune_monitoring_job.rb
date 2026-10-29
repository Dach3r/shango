# Deletes monitor results and alert deliveries past their retention, and hourly rollups after ROLLUP_DAYS. Incidents
# are kept: uptime is computed from them.
class PruneMonitoringJob < ApplicationJob
  queue_as :default

  DEFAULT_DAYS = 30
  ROLLUP_DAYS = 400
  BATCH = 1000

  def perform
    days = ENV.fetch("SHANGO_MONITOR_RESULTS_RETENTION_DAYS", DEFAULT_DAYS).to_i
    if days.positive?
      CheckResult.where(checked_at: ...days.days.ago).in_batches(of: BATCH).delete_all
      NotificationDelivery.where(created_at: ...days.days.ago).in_batches(of: BATCH).delete_all
    end
    CheckRollup.where(hour: ...ROLLUP_DAYS.days.ago).in_batches(of: BATCH).delete_all
  end
end
