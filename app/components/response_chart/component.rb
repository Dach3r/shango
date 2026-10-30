# Average response time per hour as one line (one series: no legend, the title names it), drawn in the browser by the
# `chart` Stimulus controller (Chart.js). Hours without a response leave a gap instead of a fake zero.
class ResponseChart::Component < ApplicationComponent
  def initialize(points:, label:)
    @points = points
    @label = label
  end

  def render?
    @points.any? { |_hour, ms| ms }
  end

  private

  def labels
    @points.map { |hour, _ms| l(hour, format: :short) }
  end

  def datasets
    [{ label: @label, data: @points.map(&:last) }]
  end
end
