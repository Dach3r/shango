# One check of a monitor. A check that would overlap one of the same monitor still running is discarded, never queued
# to run late. A failure below the confirmations is checked again after RETRY instead of a full interval.
class MonitorCheckJob < ApplicationJob
  RETRY = 30.seconds

  queue_as :monitoring

  limits_concurrency to: 1, key: ->(monitor_id, *) { monitor_id }, duration: 2.minutes, on_conflict: :discard

  def perform(monitor_id, config_version)
    result = Monitoring::Checks::Perform.call(monitor_id:, config_version:)
    self.class.set(wait: RETRY).perform_later(monitor_id, config_version) if result.success? && result.data[:retry]
  end
end
