# Checks of an UptimeMonitor in one hour: counts and response times (of the checks that got a response), so averages
# and charts never scan results.
class CheckRollup < ApplicationRecord
  belongs_to :uptime_monitor

  validates :hour, presence: true

  def average_ms
    responses.zero? ? nil : (response_ms_sum.to_f / responses).round
  end
end
