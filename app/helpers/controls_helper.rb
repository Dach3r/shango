# Compact form control classes shared by the editor-style screens (API Client, environments).
module ControlsHelper
  FIELD = "block rounded-lg border border-line bg-field px-3 py-2 text-sm text-ink transition placeholder:text-faint focus:border-solid focus:bg-field-focus focus:ring-2 focus:ring-solid/40 focus:outline-none disabled:opacity-50".freeze
  LABEL = "mb-1 block text-xs font-medium text-muted".freeze
  BUTTONS = {
    primary: "bg-solid text-on-solid shadow-sm hover:bg-solid-hover focus-visible:ring-solid/50",
    secondary: "bg-ink/[0.03] text-ink ring-1 ring-inset ring-line hover:bg-accent/10 hover:text-accent hover:ring-accent focus-visible:ring-solid/50",
    ghost: "text-muted hover:bg-field hover:text-ink focus-visible:ring-solid/50",
    danger: "text-danger ring-1 ring-inset ring-danger/40 hover:bg-danger/10 focus-visible:ring-danger/50",
    danger_solid: "bg-danger text-white shadow-sm hover:bg-danger/90 focus-visible:ring-danger/50"
  }.freeze
  BUTTON_BASE = "inline-flex cursor-pointer items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition focus:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-60".freeze

  # Fields fill their container unless the caller sets a width (`w-*`) or flex sizing.
  def field_classes(extra = nil)
    class_names(FIELD, ("w-full" unless extra.to_s.match?(/(\A|\s)(w-|flex-|min-w-)/)), extra)
  end

  def label_classes
    LABEL
  end

  def button_classes(variant = :secondary, extra = nil)
    class_names(BUTTON_BASE, BUTTONS.fetch(variant), extra)
  end
end
