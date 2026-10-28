class NetworkRail::Component < ApplicationComponent
  LINK = "flex h-14 w-16 shrink-0 lg:w-full items-center justify-center border-b border-line text-muted transition hover:text-ink focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50 aria-[current=page]:bg-solid aria-[current=page]:text-on-solid aria-[current=page]:hover:text-on-solid"

  GROUP = "flex shrink-0 lg:flex-col"
  SEPARATOR = "ml-3 border-l border-line lg:ml-0 lg:mt-3 lg:border-l-0 lg:border-t"

  def initialize(items:, current:, label: nil)
    @items = items
    @current = current.to_s
    @label = label
  end
end
