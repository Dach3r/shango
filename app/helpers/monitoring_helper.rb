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

  KIND_ICONS = { "http" => "globe", "tcp" => "plug", "ssl" => "shield-check", "domain" => "earth", "push" => "radio" }.freeze

  # What a monitor checks, in one line.
  def monitor_target(monitor)
    case monitor.kind
    when "http" then "#{monitor.http_method} #{monitor.url}"
    when "tcp", "ssl" then "#{monitor.host}:#{monitor.port}"
    when "domain" then monitor.host
    else t("monitoring.kinds.#{monitor.kind}")
    end
  end

  def monitor_expiry(monitor)
    t("monitoring.card.expires", date: l(monitor.expires_at.to_date, format: :long)) if monitor.expires_at
  end

  # The settings of a monitor's kind, as [label, value] pairs for its page.
  def monitor_settings(monitor)
    fields = { interval: monitor_interval_label(monitor.interval), timeout: t("monitoring.units.seconds", value: monitor.timeout), confirmations: monitor.confirmations }
    fields.merge!(expected_statuses: monitor.expected_statuses, max_response_ms: monitor_ms(monitor.max_response_ms)) if monitor.http?
    fields.merge!(days_before: monitor.days_before, expires_at: monitor.expires_at ? l(monitor.expires_at, format: :long) : "—") if monitor.ssl?
    fields.merge!(environment: monitor.environment&.name || "—", notification_channels: monitor.notification_channels.map(&:name).sort.join(", ").presence || "—")
    fields.map { |field, value| [UptimeMonitor.human_attribute_name(field), value] }
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
