# Look of runs and their items in the run screens.
module RunsHelper
  RUN_TONES = {
    "queued" => "bg-ink/10 text-muted", "running" => "bg-accent/15 text-accent", "completed" => "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400",
    "failed" => "bg-danger/15 text-danger", "cancelled" => "bg-amber-500/15 text-amber-700 dark:text-amber-400"
  }.freeze
  ITEM_ICONS = { "pending" => "circle", "running" => "loader-circle", "passed" => "circle-check", "failed" => "circle-x", "skipped" => "circle-minus" }.freeze
  ITEM_TONES = {
    "pending" => "text-faint", "running" => "text-accent animate-spin", "passed" => "text-emerald-600 dark:text-emerald-400", "failed" => "text-danger", "skipped" => "text-muted"
  }.freeze

  # Completed runs say whether anything failed; the others show their state.
  def run_label(run)
    run.completed? && run.failed_count.positive? ? t("workbench.runs.statuses.completed_with_failures") : t("workbench.runs.statuses.#{run.status}")
  end

  def run_tone(run)
    run.completed? && run.failed_count.positive? ? RUN_TONES.fetch("failed") : RUN_TONES.fetch(run.status)
  end

  def item_icon(item)
    ITEM_ICONS.fetch(item.status)
  end

  def item_tone(item)
    ITEM_TONES.fetch(item.status)
  end

  def run_duration(run)
    seconds = run.duration
    return "—" unless seconds

    seconds < 1 ? "#{(seconds * 1000).round} ms" : format("%.1f s", seconds)
  end

  def run_progress(run)
    return 0 if run.total_count.zero?

    (((run.passed_count + run.failed_count) * 100.0) / run.total_count).round
  end
end
