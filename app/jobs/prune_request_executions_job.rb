# Saved responses older than the retention window are deleted (SHANGO_HISTORY_RETENTION_DAYS, default 90; 0 keeps everything).
class PruneRequestExecutionsJob < ApplicationJob
  queue_as :default

  DEFAULT_DAYS = 90

  def perform
    days = ENV.fetch("SHANGO_HISTORY_RETENTION_DAYS", DEFAULT_DAYS).to_i
    return unless days.positive?

    RequestExecution.where(created_at: ..days.days.ago).in_batches(of: 1000).delete_all
  end
end
