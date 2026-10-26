class NavItem::Component < ApplicationComponent
  BASE = "flex items-center gap-3 rounded-xl border border-transparent px-[11px] py-2 text-sm font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50 lg:group-data-[collapsed=true]/sidebar:mx-auto lg:group-data-[collapsed=true]/sidebar:size-10 lg:group-data-[collapsed=true]/sidebar:justify-center lg:group-data-[collapsed=true]/sidebar:p-0"
  ICON = "size-4 shrink-0"
  ACTIVE = "border-line bg-card text-ink shadow-sm"
  LINK = "text-body hover:bg-card hover:text-ink"
  DISABLED = "cursor-not-allowed text-faint"

  def initialize(label:, icon:, href: nil, active: false)
    @label = label
    @icon = icon
    @href = href
    @active = active
  end

  private

  def icon_classes
    class_names(ICON, "text-accent" => @active)
  end

  def classes
    class_names(BASE, ACTIVE => @active, LINK => @href && !@active, DISABLED => !@href)
  end
end
