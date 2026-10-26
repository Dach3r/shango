class TabBar::Component < ApplicationComponent
  TAB = "relative -mb-px flex cursor-pointer items-center gap-1.5 border-b-2 border-transparent px-3 py-2 text-sm font-medium text-muted transition hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50 aria-selected:border-solid aria-selected:text-ink disabled:cursor-not-allowed disabled:text-faint disabled:hover:text-faint"

  # items: [{ name:, label:, count: nil, dot: false, disabled: false }]
  def initialize(items:, label: nil)
    @items = items
    @label = label
  end
end
