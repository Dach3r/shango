require "rails_helper"

RSpec.describe ResponseChart::Component, type: :component do
  let(:hour) { Time.zone.parse("2026-10-29 10:00:00") }

  def points(*values)
    values.each_with_index.map { |ms, index| [hour + index.hours, ms] }
  end

  it "draws one line per run of hours with data, with a tooltip on every point", :aggregate_failures do
    render_inline(described_class.new(points: points(100, 200, nil, 50, 80, nil, 30), label: "Response time"))

    expect(page).to have_css("svg[role=img][aria-label='Response time']")
    expect(page).to have_css("polyline", count: 2)
    expect(page).to have_css("circle", count: 11)
    expect(page).to have_css("title", text: "200 ms")
    expect(page).to have_css("figcaption", text: I18n.t("monitoring.chart.max", ms: 200))
  end

  it "draws a single point as a dot and leaves out the axis when compact", :aggregate_failures do
    render_inline(described_class.new(points: points(120), label: "Response time", compact: true))

    expect(page).to have_no_css("polyline")
    expect(page).to have_no_css("line")
    expect(page).to have_no_css("figcaption")
    expect(page).to have_css("circle[cx='120.0']", count: 3)
  end

  it "renders nothing without data" do
    render_inline(described_class.new(points: points(nil, nil), label: "Response time"))

    expect(page).to have_no_css("svg")
  end
end
