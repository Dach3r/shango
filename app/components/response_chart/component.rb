# Average response time per hour as one line (one series: no legend, the title names it), drawn on the server as an
# inline SVG. Each point has a hover target and a native tooltip with the hour and the value. Hours without a response
# leave a gap instead of a fake zero.
class ResponseChart::Component < ApplicationComponent
  WIDTH = 240
  HEIGHT = 64
  PADDING = 4

  def initialize(points:, label:)
    @points = points
    @label = label
  end

  def render?
    @points.any? { |_hour, ms| ms }
  end

  private

  def max
    @max ||= [@points.filter_map(&:last).max, 1].max
  end

  def x(index)
    return WIDTH / 2.0 if @points.size == 1

    PADDING + (index * (WIDTH - (2 * PADDING)) / (@points.size - 1).to_f)
  end

  def y(ms)
    HEIGHT - PADDING - (ms * (HEIGHT - (2 * PADDING)) / max.to_f)
  end

  # One path per run of consecutive hours with a value, so missing hours show as gaps.
  def segments
    @points.each_with_index.slice_when { |((_, first), _), ((_, second), _)| first.nil? != second.nil? }
           .reject { |run| run.first.first.last.nil? }
           .map { |run| run.map { |(_hour, ms), index| "#{x(index).round(1)},#{y(ms).round(1)}" } }
  end

  def marks
    @points.each_with_index.filter_map { |(hour, ms), index| [x(index).round(1), y(ms).round(1), hour, ms] if ms }
  end
end
