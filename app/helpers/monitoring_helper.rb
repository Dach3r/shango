module MonitoringHelper
  def monitor_interval_label(seconds)
    return t("monitoring.intervals.hours", value: seconds / 3600) if (seconds % 3600).zero?

    t("monitoring.intervals.minutes", value: seconds / 60)
  end

  def monitor_interval_options(monitor)
    monitor.intervals.map { |seconds| [monitor_interval_label(seconds), seconds] }
  end

  def monitor_uptime(percent)
    percent ? number_to_percentage(percent, precision: 2, strip_insignificant_zeros: true) : "—"
  end

  def monitor_ms(ms)
    ms ? t("monitoring.units.ms", value: number_with_delimiter(ms)) : "—"
  end

  # Why a check or an incident failed, in words.
  def monitor_cause(error, detail = nil)
    text = t("monitoring.causes.#{error}")
    detail.present? ? "#{text} (#{detail})" : text
  end

  CHANNEL_ICONS = { "email" => "mail", "webhook" => "webhook", "slack" => "slack", "discord" => "message-circle" }.freeze

  def channel_icon(channel)
    CHANNEL_ICONS.fetch(channel.is_a?(NotificationChannel) ? channel.kind : channel.to_s)
  end

  # Why the latest delivery of a channel failed, in words.
  def channel_delivery_error(delivery)
    text = t("monitoring.delivery_errors.#{delivery.error}")
    delivery.detail.present? ? "#{text} (#{delivery.detail})" : text
  end
end
