require "rails_helper"

RSpec.describe Monitoring::Uptime do
  let(:now) { Time.zone.parse("2026-10-29 12:00:00") }
  let(:monitor) { build(:uptime_monitor, created_at: now - 10.days, last_checked_at: now - 1.minute) }

  def incident(started, resolved = nil)
    build(:incident, started_at: now - started, resolved_at: resolved && now - resolved)
  end

  it "subtracts the time incidents lasted within the span", :aggregate_failures do
    expect(described_class.percent(monitor, [], 24.hours, now:)).to eq(100.0)
    expect(described_class.percent(monitor, [incident(3.hours, 2.hours + 48.minutes)], 24.hours, now:)).to eq(99.17)
    expect(described_class.percent(monitor, [incident(2.days, 1.day + 12.hours)], 24.hours, now:)).to eq(100.0)
    expect(described_class.percent(monitor, [incident(30.hours)], 24.hours, now:)).to eq(0.0)
  end

  it "starts the span when the monitor was created" do
    monitor.created_at = now - 2.hours

    expect(described_class.percent(monitor, [incident(1.hour)], 24.hours, now:)).to eq(50.0)
  end

  it "has no uptime before the first check and is whole for a monitor created this instant", :aggregate_failures do
    expect(described_class.percent(build(:uptime_monitor, last_checked_at: nil), [], 24.hours, now:)).to be_nil

    monitor.created_at = now

    expect(described_class.percent(monitor, [], 24.hours, now:)).to eq(100.0)
  end
end
