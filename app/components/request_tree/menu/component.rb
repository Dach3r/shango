class RequestTree::Menu::Component < ApplicationComponent
  ITEM = "flex w-full cursor-pointer items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-sm text-body transition hover:bg-field hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50"

  # trigger: false hides the "…" button when the menu only opens from a right click.
  def initialize(label:, trigger: true)
    @label = label
    @trigger = trigger
  end
end
