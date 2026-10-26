class ZoomPicker::Component < ApplicationComponent
  private

  def levels
    Zooming::LEVELS
  end

  def default?(level)
    level == Zooming::NEUTRAL
  end

  def current?(level)
    helpers.current_zoom == level
  end
end
