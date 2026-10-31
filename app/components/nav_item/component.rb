class NavItem::Component < ApplicationComponent
  BASE = "flex items-center gap-2.5 px-3 text-base font-medium transition focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50"
  ORIENTATIONS = {
    vertical: { base: "h-11 border-b border-line", active: "bg-field shadow-[inset_2px_0_0_var(--accent)]", label: "", badge: false },
    menu: { base: "h-10 w-full px-4 text-sm", active: "bg-field shadow-[inset_2px_0_0_var(--accent)]", label: "flex-1", badge: true },
    settings: { base: "h-10 w-full px-4 text-sm", active: "bg-accent/10", label: "flex-1", badge: true }
  }.freeze
  ACTIVE = "font-semibold text-accent"
  LINK = "text-body hover:bg-field hover:text-ink"
  DISABLED = "cursor-not-allowed text-faint"

  def initialize(label:, icon:, href: nil, active: false, orientation: :vertical, badge: nil)
    @label = label
    @icon = icon
    @href = href
    @active = active
    @badge = badge
    @orientation = ORIENTATIONS.fetch(orientation)
  end

  private

  def label_classes
    class_names("truncate", @orientation[:label])
  end

  def classes
    class_names(BASE, @orientation[:base], ACTIVE => @active, @orientation[:active] => @active, LINK => @href && !@active, DISABLED => !@href)
  end
end
