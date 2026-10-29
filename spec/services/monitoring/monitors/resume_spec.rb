require "rails_helper"

RSpec.describe Monitoring::Monitors::Resume do
  it "checks the monitor again from scratch on the next dispatch", :aggregate_failures do
    monitor = create(:uptime_monitor, enabled: false, failures: 2)
    monitor.go_down
    monitor.save!
    at = Time.current.change(usec: 0)

    expect(described_class.call(monitor:, at:)).to be_success
    expect(monitor.reload).to have_attributes(enabled: true, status: "pending", failures: 0, next_check_at: at, last_status_change_at: at)
  end

  it "records who resumed it" do
    monitor = create(:uptime_monitor, enabled: false)
    described_class.call(monitor:, actor: monitor.creator)

    expect(AuditEvent.sole.kind).to eq("monitor_resumed")
  end

  it "gives a push monitor a whole interval and grace to ping again" do
    at = Time.current.change(usec: 0)
    monitor = create(:uptime_monitor, :push, interval: 3600, enabled: false)
    described_class.call(monitor:, at:)

    expect(monitor.reload.next_check_at).to eq(at + 3900)
  end
end
