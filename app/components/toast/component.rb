class Toast::Component < ApplicationComponent
  KINDS = {
    notice: { icon: "circle-check", role: "status", tone: "text-accent", border: "border-solid" },
    alert: { icon: "circle-alert", role: "alert", tone: "text-danger", border: "border-danger" }
  }.freeze
  BASE = "pointer-events-auto relative flex w-full items-center gap-3 rounded-2xl border bg-card py-3 pr-3 pl-4 text-sm shadow-lg shadow-night-1000/10 transition duration-200 ease-out starting:translate-y-2 starting:opacity-0 data-[state=closed]:translate-y-2 data-[state=closed]:opacity-0"

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
    class_names(BASE, config[:tone], config[:border], @options[:class])
  end
end
