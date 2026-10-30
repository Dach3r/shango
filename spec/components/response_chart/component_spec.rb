require "rails_helper"

RSpec.describe ResponseChart::Component, type: :component do
  let(:hour) { Time.zone.parse("2026-10-29 10:00:00") }

  def points(*values)
    values.each_with_index.map { |ms, index| [hour + index.hours, ms] }
  end

  it "hands the hours and values to the chart controller, keeping gaps as null", :aggregate_failures do
    render_inline(described_class.new(points: points(100, nil, 50), label: "Response time"))

    figure = page.find("figure[data-controller=chart]")
    expect(figure["data-chart-unit-value"]).to eq("ms")
    expect(JSON.parse(figure["data-chart-labels-value"])).to eq((0..2).map { |i| I18n.l(hour + i.hours, format: :short) })
    expect(JSON.parse(figure["data-chart-datasets-value"])).to eq([{ "label" => "Response time", "data" => [100, nil, 50] }])
    expect(page).to have_css("canvas[data-chart-target=canvas][role=img][aria-label='Response time']")
  end

  it "renders nothing without data" do
    render_inline(described_class.new(points: points(nil, nil), label: "Response time"))

    expect(page).to have_no_css("canvas")
  end
end
