require "rails_helper"

RSpec.describe Monitoring::Monitors::Report do
  let(:now) { Time.zone.parse("2026-10-29 12:30:00") }
  let(:monitor) { create(:uptime_monitor, created_at: now - 40.days, last_checked_at: now - 1.minute) }

  it "reports uptime per span, the average, points, incidents open first and latest checks", :aggregate_failures do
    create(:check_rollup, uptime_monitor: monitor, hour: now.beginning_of_hour, responses: 4, response_ms_sum: 400)
    old = create(:incident, uptime_monitor: monitor, started_at: now - 5.days, resolved_at: now - 5.days + 168.minutes)
    open = create(:incident, uptime_monitor: monitor, started_at: now - 72.minutes)
    create(:incident, uptime_monitor: monitor, started_at: now - 60.days, resolved_at: now - 59.days)
    checks = Array.new(2) { |index| create(:check_result, uptime_monitor: monitor, checked_at: now - index.minutes) }
    report = described_class.call(monitor:, now:).record

    expect(report.uptime).to eq(day: 95.0, week: 97.62, month: 99.44)
    expect(report.average_ms).to eq(100)
    expect(report.points).to eq([[now.beginning_of_hour, 100]])
    expect(report.incidents.first(2)).to eq([open, old])
    expect(report.checks).to eq(checks)
  end
end
