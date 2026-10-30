# The last 24 hours of a monitor as one bar per hour (`Monitoring::Monitors::Overview::Hour`), each with a native
# tooltip that names the hour and its checks; status colors only mark states, the tooltip carries the words.
class UptimeStrip::Component < ApplicationComponent
  TONES = { up: "bg-emerald-500", degraded: "bg-danger/50", down: "bg-danger", empty: "bg-line" }.freeze

  def initialize(hours:, label:)
    @hours = hours
    @label = label
  end

  def call
    tag.div(role: "img", aria: { label: @label }, class: "flex h-6 w-full min-w-0 items-stretch gap-px") do
      safe_join(@hours.map { |hour| tag.span(title: title(hour), class: class_names("min-w-0 flex-1 transition hover:opacity-70", TONES.fetch(hour.state))) })
    end
  end

  private

  def title(hour)
    time = I18n.l(hour.hour, format: :short)
    return I18n.t("monitoring.strip.empty", hour: time) if hour.state == :empty

    I18n.t("monitoring.strip.hour", hour: time, checks: hour.checks, failures: hour.failures)
  end
end
