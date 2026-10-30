require "rails_helper"

RSpec.describe UptimeStrip::Component, type: :component do
  let(:hour) { Time.zone.parse("2026-10-29 10:00:00") }

  def slot(checks, failures, ago = 0)
    Monitoring::Monitors::Overview::Hour.new(hour: hour - ago.hours, checks:, failures:)
  end

  it "draws one bar per hour, colored by its state, with the checks in the tooltip", :aggregate_failures do
    render_inline(described_class.new(hours: [slot(0, 0, 3), slot(12, 0, 2), slot(12, 4, 1), slot(12, 12)], label: "Last 24 h"))

    expect(page).to have_css("[role=img][aria-label='Last 24 h'] span", count: 4)
    expect(page).to have_css("span.bg-line[title='#{I18n.t("monitoring.strip.empty", hour: I18n.l(hour - 3.hours, format: :short))}']")
    expect(page).to have_css("span.bg-emerald-500")
    expect(page).to have_css("span.bg-danger\\/50[title='#{I18n.t("monitoring.strip.hour", hour: I18n.l(hour - 1.hour, format: :short), checks: 12, failures: 4)}']")
    expect(page).to have_css("span.bg-danger")
  end
end
