class Select::Component < ApplicationComponent
  include ControlsHelper

  SEARCH_THRESHOLD = 7
  LARGE_TRIGGER = "#{Input::Component::FIELD} #{CONTROL_SIZE} flex! cursor-pointer items-center justify-between gap-3 text-left".freeze
  OPTION = "flex w-full cursor-pointer items-center gap-2 text-left text-sm text-body transition hover:bg-field hover:text-ink aria-selected:text-ink data-[active]:bg-field data-[active]:text-ink focus-visible:outline-none"

  # options: [[label, value], ...]. Search shows by default once there are more than SEARCH_THRESHOLD options.
  # dock: true opens the menu as a side panel pinned to the right edge of the nearest positioned ancestor, below its tab bar.
  # dock_top is the offset class of the panel below the top edge (the height of the bar that stays visible above it); dock_width is its width class.
  # keep_open lists the values whose option leaves the menu open (their block content, rendered under the list, is what the person fills next).
  # input_data goes on the hidden input (it dispatches `change`); class sizes the control like any field (`w-28`, `font-mono`).
  # large: true draws the trigger like Input::Component, for the forms built with it.
  def initialize(name:, options:, value: nil, id: nil, label: nil, searchable: nil, disabled: false, dock: false, dock_top: "top-[2.375rem]", dock_width: "w-56", keep_open: [], input_data: {}, large: false, **html)
    @name = name
    @options = options
    @value = value.to_s
    @id = id
    @label = label
    @searchable = searchable
    @disabled = disabled
    @dock = dock
    @dock_top = dock_top
    @dock_width = dock_width
    @keep_open = keep_open.map(&:to_s)
    @input_data = input_data
    @large = large
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
    class_names((@dock ? "static!" : "relative"), ("w-full" unless @class.to_s.match?(/(\A|\s)(w-|flex-|min-w-)/)), @class.to_s.split.grep(/\A(w-|flex-|min-w-|max-w-|shrink-)/))
  end

  def trigger_classes
    own = @class.to_s.split.reject { |c| c.match?(/\A(w-|flex-|min-w-|max-w-|shrink-)/) }
    return class_names(LARGE_TRIGGER, own) if @large

    field_classes(["flex! cursor-pointer items-center justify-between gap-2 text-left", own].flatten.join(" "))
  end

  def menu_classes
    return "absolute right-0 #{@dock_top} bottom-0 z-30 #{@dock_width} overflow-y-auto border-l border-line bg-card" if @dock

    "absolute left-0 top-full z-30 mt-1.5 w-max min-w-full max-w-80 border border-line bg-card p-1"
  end

  def list_classes
    class_names("overflow-y-auto", ("max-h-60" unless @dock))
  end

  def option_classes
    return class_names(OPTION, "border-b border-line px-5 py-3.5") if @dock

    class_names(OPTION, (@large ? "px-3 py-2.5" : "px-2.5 py-1.5"))
  end
end
