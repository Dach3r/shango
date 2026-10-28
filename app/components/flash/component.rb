class Flash::Component < ApplicationComponent
  KINDS = {
    notice: { icon: "circle-check", role: "status", tone: "text-accent", edge: "border-l-accent", bar: "bg-accent" },
    alert: { icon: "circle-alert", role: "alert", tone: "text-danger", edge: "border-l-danger", bar: "bg-danger" }
  }.freeze
  BASE = "group pointer-events-auto relative w-full max-w-md overflow-hidden border border-l-2 border-line bg-card text-sm text-ink transition duration-300 ease-out starting:-translate-y-2 starting:opacity-0 data-[state=closed]:-translate-y-2 data-[state=closed]:opacity-0"

  def initialize(message:, kind: :notice, **options)
    @message = message
    @kind = KINDS.key?(kind.to_sym) ? kind.to_sym : :notice
    @options = options
  end

  private

  def config
    KINDS.fetch(@kind)
  end

  def classes
    class_names(BASE, config[:edge], @options[:class])
  end
end
