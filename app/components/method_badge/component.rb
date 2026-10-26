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

  BASE = "font-mono text-[0.6875rem] font-semibold tracking-tight".freeze

  # Short label and classes per method, so the client can restyle badges when the method changes before saving.
  def self.presets
    COLORS.to_h { |method, color| [method, { label: ABBREVIATIONS.fetch(method, method), classes: "#{BASE} #{color}" }] }
  end

  def initialize(method:, short: false, request_id: nil)
    @method = method.to_s.upcase
    @short = short
    @request_id = request_id
  end

  def call
    tag.span(label, class: class_names(BASE, COLORS.fetch(@method, "text-muted")), data: { method_badge: @request_id })
  end

  private

  def label
    @short ? ABBREVIATIONS.fetch(@method, @method) : @method
  end
end
