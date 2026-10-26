class StatusBadge::Component < ApplicationComponent
  TONES = {
    success: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400",
    client_error: "bg-amber-500/15 text-amber-700 dark:text-amber-400",
    server_error: "bg-danger/15 text-danger",
    error: "bg-danger/15 text-danger"
  }.freeze

  def initialize(execution:)
    @execution = execution
  end

  def call
    tag.span(label, class: class_names("inline-flex items-center gap-1 px-2 py-0.5 text-xs font-semibold", TONES.fetch(@execution.status_class)))
  end

  private

  def label
    return t("workbench.executions.error") if @execution.error?

    [@execution.status, @execution.status_text].compact_blank.join(" ")
  end
end
