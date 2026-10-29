# A notification channel that a monitor alerts. Both belong to the same project.
class MonitorChannel < ApplicationRecord
  PER_MONITOR = 10

  belongs_to :uptime_monitor
  belongs_to :notification_channel

  validates :notification_channel_id, uniqueness: { scope: :uptime_monitor_id }
  validate :same_project
  validate :within_limit, on: :create

  private

  def same_project
    errors.add(:notification_channel, :invalid) if uptime_monitor && notification_channel && uptime_monitor.project_id != notification_channel.project_id
  end

  def within_limit
    errors.add(:base, :monitor_limit, count: PER_MONITOR) if uptime_monitor && uptime_monitor.monitor_channels.where.not(id:).count >= PER_MONITOR
  end
end
