class Select::Component < ApplicationComponent
  include ControlsHelper

  SEARCH_THRESHOLD = 7
  OPTION = "flex w-full cursor-pointer items-center gap-2 px-2.5 py-1.5 text-left text-sm text-body transition hover:bg-field hover:text-ink aria-selected:text-ink data-[active]:bg-field data-[active]:text-ink focus-visible:outline-none"

  # options: [[label, value], ...]. Search shows by default once there are more than SEARCH_THRESHOLD options.
  # align: :right anchors the menu to the trigger's right edge, for controls at the end of a row.
  # input_data goes on the hidden input (it dispatches `change`); class sizes the control like any field (`w-28`, `font-mono`).
  def initialize(name:, options:, value: nil, id: nil, label: nil, searchable: nil, disabled: false, align: :left, input_data: {}, **html)
    @name = name
    @options = options
    @value = value.to_s
    @id = id
    @label = label
    @searchable = searchable
    @disabled = disabled
    @align = align
    @input_data = input_data
    @class = html[:class]
  end

  private

  def searchable?
    @searchable.nil? ? @options.size > SEARCH_THRESHOLD : @searchable
  end

  def selected
    @options.find { |_label, value| value.to_s == @value } || @options.first
  end

  def selected_value
    selected&.last.to_s
  end

  def selected_label
    selected&.first
  end

  def wrapper_classes
    class_names("relative", ("w-full" unless @class.to_s.match?(/(\A|\s)(w-|flex-|min-w-)/)), @class.to_s.split.grep(/\A(w-|flex-|min-w-|max-w-|shrink-)/))
  end

  def trigger_classes
    field_classes(["flex! cursor-pointer items-center justify-between gap-2 text-left", @class.to_s.split.reject { |c| c.match?(/\A(w-|flex-|min-w-|max-w-|shrink-)/) }].flatten.join(" "))
  end

  def menu_classes
    class_names("absolute top-full z-30 mt-1.5 w-max min-w-full max-w-80 border border-line bg-card p-1", (@align == :right ? "right-0" : "left-0"))
  end

  def option_classes
    OPTION
  end
end
