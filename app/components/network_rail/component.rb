class NetworkRail::Component < ApplicationComponent
  TAB = "flex h-12 w-16 shrink-0 cursor-pointer items-center justify-center border-b-2 border-transparent text-muted transition hover:text-ink focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50 aria-selected:border-accent aria-selected:bg-card aria-selected:text-ink lg:border-b-0 lg:border-l-2"

  # items: [{ name:, label:, icon: }]. Drives the `tabs` Stimulus controller of its ancestor; icon-only, so the label is also the tooltip.
  def initialize(items:, label: nil)
    @items = items
    @label = label
  end
end
