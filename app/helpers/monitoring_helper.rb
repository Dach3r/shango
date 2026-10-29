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
end
