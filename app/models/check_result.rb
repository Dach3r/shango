# One check of an UptimeMonitor. Append-only; pruned after the retention period (see docs/monitoring.md §8).
class CheckResult < ApplicationRecord
  belongs_to :uptime_monitor

  enum :status, { up: "up", down: "down", unknown: "unknown" }

  validates :checked_at, presence: true

  scope :recent, -> { order(checked_at: :desc) }
end
