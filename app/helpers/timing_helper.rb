module TimingHelper
  TIMING_TONES = {
    "dns" => "bg-amber-400", "tcp" => "bg-sky-500", "tls" => "bg-indigo-500", "ttfb" => "bg-rose-500", "download" => "bg-emerald-500", "process" => "bg-zinc-500"
  }.freeze
  MIN_TIMING_WIDTH = 1.0

  # Waterfall rows for an execution's timings: phase, duration and the bar's left offset / width as percentages of the total.
  def timing_rows(execution)
    timings = execution.timings
    total = timings.values.sum
    return [] unless total.positive?

    offset = 0.0
    TIMING_TONES.filter_map do |phase, tone|
      milliseconds = timings[phase]
      next if milliseconds.nil? || (phase == "tls" && milliseconds.zero?)

      width = [milliseconds / total * 100, MIN_TIMING_WIDTH].max
      left = [offset / total * 100, 100 - width].min
      offset += milliseconds
      { phase:, tone:, milliseconds:, left:, width: }
    end
  end
end
