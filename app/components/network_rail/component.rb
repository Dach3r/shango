class NetworkRail::Component < ApplicationComponent
  LINK = "flex h-12 w-16 shrink-0 items-center justify-center border-b-2 border-transparent text-muted transition hover:text-ink focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50 aria-[current=page]:border-accent aria-[current=page]:bg-card aria-[current=page]:text-ink lg:border-b-0 lg:border-l-2"

  # items: [{ name:, label:, icon:, path: }]; `current` is the name of the tool on display. Icon-only, so the label is also the tooltip.
  def initialize(items:, current:, label: nil)
    @items = items
    @current = current.to_s
    @label = label
  end
end
