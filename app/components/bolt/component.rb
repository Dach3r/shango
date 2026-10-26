class Bolt::Component < ApplicationComponent
  POINTS = "58,0 12,64 44,64 34,120 88,46 54,46".freeze

  def initialize(**options)
    @options = options
  end

  def call
    tag.svg(tag.polygon(points: POINTS, "stroke-linejoin": "round"), viewBox: "0 0 100 120", "aria-hidden": true, **@options)
  end
end
