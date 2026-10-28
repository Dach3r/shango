class Flash::Component < ApplicationComponent
  KINDS = {
    notice: { icon: "circle-check", role: "status", tone: "bg-solid", glyph: "border-solid" },
    alert: { icon: "circle-alert", role: "alert", tone: "bg-danger", glyph: "border-danger" }
  }.freeze
  BASE = "pointer-events-auto relative w-full border-b border-line bg-card text-sm text-ink transition duration-300 ease-out starting:-translate-y-full data-[state=closed]:-translate-y-full"

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
    class_names(BASE, config[:glyph], @options[:class])
  end
end
