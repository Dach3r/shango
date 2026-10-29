require "rails_helper"

RSpec.describe Monitoring::Probes::Push do
  let(:now) { Time.utc(2026, 10, 29, 12) }
  let(:monitor) { build(:uptime_monitor, :push, interval: 3600, settings: { "grace" => 300 }, created_at: now - 2.days) }

  it "has nothing to say while a ping came within interval plus grace" do
    monitor.last_pinged_at = now - 3899

    expect(described_class.call(monitor, now:)).to be_nil
  end

  it "is down once overdue, naming the last ping", :aggregate_failures do
    monitor.last_pinged_at = now - 3900

    expect(described_class.call(monitor, now:)).to have_attributes(status: "down", error: "no_ping", detail: "2026-10-29T10:55:00Z")
  end

  it "counts from creation, resuming or the last change of state when there was no later ping", :aggregate_failures do
    expect(described_class.call(monitor, now:)).to have_attributes(error: "no_ping", detail: nil)
    monitor.last_status_change_at = now - 10.minutes
    expect(described_class.call(monitor, now:)).to be_nil
  end
end
