module MonitoringHelper
  def monitor_interval_label(seconds)
    return t("monitoring.intervals.days", value: seconds / 86_400) if (seconds % 86_400).zero?
    return t("monitoring.intervals.hours", value: seconds / 3600) if (seconds % 3600).zero?

    t("monitoring.intervals.minutes", value: seconds / 60)
  end

  def monitor_interval_options(monitor)
    monitor.intervals.map { |seconds| [monitor_interval_label(seconds), seconds] }
  end

  # A grace period: none, minutes or hours.
  def monitor_grace_label(seconds)
    return t("monitoring.durations.none") if seconds.zero?
    return t("monitoring.durations.hours", value: seconds / 3600) if (seconds % 3600).zero?

    t("monitoring.durations.minutes", value: seconds / 60)
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
    when "http" then monitor.mode == "request" ? monitor_request_name(monitor.api_request) : "#{monitor.http_method} #{monitor.url}"
    when "tcp", "ssl" then "#{monitor.host}:#{monitor.port}"
    when "domain" then monitor.host
    else monitor.last_pinged_at ? t("monitoring.card.last_ping", time: time_ago_in_words(monitor.last_pinged_at)) : t("monitoring.card.no_ping")
    end
  end

  def monitor_request_name(request)
    request ? "#{request.http_method} #{request.collection.name} / #{request.name}" : t("monitoring.causes.request_missing")
  end

  # The project's saved requests by collection, for the request picker of an HTTP monitor.
  def monitor_request_options
    current_project.collections.ordered.includes(:api_requests).filter_map do |collection|
      requests = collection.api_requests.sort_by { |request| [request.name.to_s.downcase, request.id] }
      [collection.name, requests.map { |request| ["#{request.http_method} #{request.name}", request.id] }] if requests.any?
    end
  end

  def monitor_expiry(monitor)
    t("monitoring.card.expires", date: l(monitor.expires_at.to_date, format: :long)) if monitor.expires_at
  end

  # The settings of a monitor's kind, as [label, value] pairs for its page.
  def monitor_settings(monitor)
    fields = { interval: monitor_interval_label(monitor.interval) }
    fields[:timeout] = t("monitoring.units.seconds", value: monitor.timeout) unless monitor.push?
    fields[:confirmations] = monitor.confirmations
    fields.merge!(expected_statuses: monitor.expected_statuses, max_response_ms: monitor_ms(monitor.max_response_ms)) if monitor.http?
    fields.merge!(days_before: monitor.days_before, expires_at: monitor.expires_at ? l(monitor.expires_at, format: :long) : "—") if monitor.ssl? || monitor.domain?
    fields.merge!(grace: monitor_grace_label(monitor.grace), last_pinged_at: monitor.last_pinged_at ? l(monitor.last_pinged_at, format: :long) : "—") if monitor.push?
    fields.merge!(environment: monitor.environment&.name || "—", notification_channels: monitor.notification_channels.map(&:name).sort.join(", ").presence || "—")
    fields.map { |field, value| [UptimeMonitor.human_attribute_name(field), value] }
  end

  ICON_ACTION = "flex size-8 cursor-pointer items-center justify-center text-muted transition hover:bg-field hover:text-ink focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50".freeze

  # Options of one action button of a monitor or channel: a labelled button, or a square icon named by its tooltip when
  # compact. The label defaults to the monitor action `name`.
  def monitor_action(name, compact:, danger: false, label: t("monitoring.actions.#{name}"))
    return { class: button_classes(danger ? :danger : :secondary) } unless compact

    { class: class_names(ICON_ACTION, "hover:text-danger" => danger), title: label, aria: { label: } }
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
