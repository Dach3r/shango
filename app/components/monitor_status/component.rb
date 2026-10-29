# The state of a monitor (`up`, `down`, `pending`, or `paused` when it is disabled) or of one check (`up`, `down`,
# `unknown`), as a dot and a label; status colors are reserved for states and always come with the label.
class MonitorStatus::Component < ApplicationComponent
  TONES = {
    up: "text-emerald-700 dark:text-emerald-400", down: "text-danger", paused: "text-amber-700 dark:text-amber-400",
    pending: "text-muted", unknown: "text-muted"
  }.freeze

  def self.for(monitor)
    new(status: monitor.paused? ? :paused : monitor.status)
  end

  def initialize(status:)
    @status = status.to_sym
  end

  def call
    tag.span(class: class_names("inline-flex items-center gap-1.5 font-mono text-[0.6875rem] font-medium tracking-wide whitespace-nowrap uppercase", TONES.fetch(@status))) do
      safe_join([tag.span(class: "size-1.5 rounded-full bg-current", aria: { hidden: true }), t("monitoring.statuses.#{@status}")])
    end
  end
end
