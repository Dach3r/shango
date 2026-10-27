# Saved network runs older than the retention window are deleted (SHANGO_NETWORK_HISTORY_RETENTION_DAYS, default 90; 0 keeps everything).
class PruneNetworkChecksJob < ApplicationJob
  queue_as :default

  DEFAULT_DAYS = 90

  def perform
    days = ENV.fetch("SHANGO_NETWORK_HISTORY_RETENTION_DAYS", DEFAULT_DAYS).to_i
    return unless days.positive?

    NetworkCheck.where(created_at: ..days.days.ago).in_batches(of: 1000).delete_all
  end
end
