class NavItem::Component < ApplicationComponent
  BASE = "flex items-center gap-3 border-b border-line h-14 px-3 text-base font-medium transition focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50"
  COLLAPSIBLE = "lg:group-data-[collapsed=true]/sidebar:justify-center lg:group-data-[collapsed=true]/sidebar:px-0"
  LABEL_COLLAPSIBLE = "lg:group-data-[collapsed=true]/sidebar:hidden"
  ACTIVE = "bg-field shadow-[inset_2px_0_0_var(--accent)] font-semibold text-accent"
  LINK = "text-body hover:bg-field hover:text-ink"
  DISABLED = "cursor-not-allowed text-faint"

  def initialize(label:, icon:, href: nil, active: false, collapsible: true)
    @label = label
    @icon = icon
    @href = href
    @active = active
    @collapsible = collapsible
  end

  private

  def label_classes
    class_names("truncate", LABEL_COLLAPSIBLE => @collapsible)
  end

  def classes
    class_names(BASE, COLLAPSIBLE => @collapsible, ACTIVE => @active, LINK => @href && !@active, DISABLED => !@href)
  end
end
