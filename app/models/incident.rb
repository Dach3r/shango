# A period during which an UptimeMonitor was down. At most one is open per monitor; uptime is computed from
# incident durations.
class Incident < ApplicationRecord
  belongs_to :project
  belongs_to :uptime_monitor

  enum :resolution, { recovered: "recovered", paused: "paused" }

  validates :cause, :started_at, presence: true

  scope :open, -> { where(resolved_at: nil) }
  scope :recent, -> { order(started_at: :desc) }

  def open?
    resolved_at.nil?
  end

  # Seconds of this incident inside `window` (a range of times); an open incident lasts until the window ends.
  def seconds_within(window)
    first = [started_at, window.begin].max
    last = [resolved_at || window.end, window.end].min
    [last - first, 0].max
  end
end
