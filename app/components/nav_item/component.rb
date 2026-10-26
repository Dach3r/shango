class NavItem::Component < ApplicationComponent
  BASE = "relative flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50 lg:group-data-[collapsed=true]/sidebar:mx-auto lg:group-data-[collapsed=true]/sidebar:size-10 lg:group-data-[collapsed=true]/sidebar:justify-center lg:group-data-[collapsed=true]/sidebar:p-0"
  ACTIVE = "bg-field text-ink before:absolute before:-left-3 before:inset-y-2 before:w-1 before:rounded-r-full before:bg-accent"
  LINK = "text-body hover:bg-field hover:text-ink"
  DISABLED = "cursor-not-allowed text-faint"

  def initialize(label:, icon:, href: nil, active: false)
    @label = label
    @icon = icon
    @href = href
    @active = active
  end

  private

  def classes
    class_names(BASE, ACTIVE => @active, LINK => @href && !@active, DISABLED => !@href)
  end
end
