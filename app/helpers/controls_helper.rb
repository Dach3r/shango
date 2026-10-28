# Compact form control classes shared by the editor-style screens (API Client, environments).
module ControlsHelper
  FIELD = "block border border-line bg-field px-3 py-2 text-sm text-ink transition placeholder:text-faint focus:border-solid focus:bg-field-focus focus:ring-1 focus:ring-solid focus:outline-none disabled:opacity-50".freeze
  BAR_FIELD = "bg-ink/[0.05] focus:border-line! focus:bg-ink/[0.08]! focus:ring-0!".freeze
  LABEL = "mb-1 block text-xs font-medium text-muted".freeze
  BUTTONS = {
    primary: "bg-solid text-on-solid hover:bg-solid-hover focus-visible:ring-solid/50",
    secondary: "text-ink ring-1 ring-inset ring-line hover:bg-field hover:text-accent hover:ring-accent focus-visible:ring-solid/50",
    ghost: "text-muted hover:bg-field hover:text-ink focus-visible:ring-solid/50",
    danger: "text-danger ring-1 ring-inset ring-danger/40 hover:bg-danger/10 focus-visible:ring-danger/50",
    danger_solid: "bg-danger text-white hover:bg-danger/90 focus-visible:ring-danger/50"
  }.freeze
  BUTTON_BASE = "inline-flex cursor-pointer whitespace-nowrap items-center justify-center gap-2 px-3 py-2 text-sm font-medium transition focus:outline-none focus-visible:ring-1 disabled:cursor-not-allowed disabled:opacity-60".freeze

  # Fields fill their container unless the caller sets a width (`w-*`) or flex sizing.
  def field_classes(extra = nil)
    class_names(FIELD, ("w-full" unless extra.to_s.match?(/(\A|\s)(w-|flex-|min-w-)/)), extra)
  end

  # Inline form-bar fields: focus only shifts the background, no border or ring.
  def bar_field_classes(extra = nil)
    field_classes(class_names(BAR_FIELD, extra))
  end

  def label_classes
    LABEL
  end

  def button_classes(variant = :secondary, extra = nil)
    class_names(BUTTON_BASE, BUTTONS.fetch(variant), extra)
  end
end
