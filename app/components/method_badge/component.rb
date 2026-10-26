class MethodBadge::Component < ApplicationComponent
  COLORS = {
    "GET" => "text-emerald-700 dark:text-emerald-400",
    "POST" => "text-amber-700 dark:text-amber-400",
    "PUT" => "text-sky-700 dark:text-sky-400",
    "PATCH" => "text-violet-700 dark:text-violet-400",
    "DELETE" => "text-danger",
    "HEAD" => "text-muted",
    "OPTIONS" => "text-muted"
  }.freeze
  ABBREVIATIONS = { "DELETE" => "DEL", "OPTIONS" => "OPT", "PATCH" => "PAT" }.freeze

  def initialize(method:, short: false)
    @method = method.to_s.upcase
    @short = short
  end

  def call
    tag.span(label, class: class_names("font-mono text-[11px] font-semibold tracking-tight", COLORS.fetch(@method, "text-muted")))
  end

  private

  def label
    @short ? ABBREVIATIONS.fetch(@method, @method) : @method
  end
end
