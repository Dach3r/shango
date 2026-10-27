class NetworkStatus::Component < ApplicationComponent
  TONES = {
    success: "text-emerald-700 dark:text-emerald-400",
    warning: "text-amber-700 dark:text-amber-400",
    danger: "text-danger",
    neutral: "text-muted"
  }.freeze
  STATUS_TONES = {
    ok: :success, match: :success, open: :success,
    cname: :neutral, closed: :neutral,
    nodata: :warning, nxdomain: :warning, mismatch: :warning, no_answer: :warning, timeout: :warning, filtered: :warning,
    servfail: :danger, refused: :danger, error: :danger, blocked: :danger, unresolved: :danger
  }.freeze

  def initialize(status:)
    @status = status.to_sym
  end

  def call
    tag.span(class: class_names("inline-flex items-center gap-1.5 font-mono text-[0.6875rem] font-medium tracking-wide whitespace-nowrap uppercase", TONES.fetch(STATUS_TONES.fetch(@status)))) do
      safe_join([tag.span(class: "size-1.5 rounded-full bg-current", aria: { hidden: true }), t("network.statuses.#{@status}")])
    end
  end
end
