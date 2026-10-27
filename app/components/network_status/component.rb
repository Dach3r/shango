class NetworkStatus::Component < ApplicationComponent
  TONES = {
    success: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400",
    warning: "bg-amber-500/15 text-amber-700 dark:text-amber-400",
    danger: "bg-danger/15 text-danger",
    neutral: "bg-field text-muted"
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
    tag.span(t("network.statuses.#{@status}"), class: class_names("inline-flex items-center gap-1 px-2 py-0.5 text-xs font-semibold", TONES.fetch(STATUS_TONES.fetch(@status))))
  end
end
