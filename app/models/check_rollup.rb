# Checks of an UptimeMonitor in one hour: counts and response times, so averages and charts never scan results.
class CheckRollup < ApplicationRecord
  belongs_to :uptime_monitor

  validates :hour, presence: true

  def average_ms
    checks.zero? ? nil : (response_ms_sum.to_f / checks).round
  end
end
