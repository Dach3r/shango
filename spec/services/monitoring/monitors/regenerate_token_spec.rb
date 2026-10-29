require "rails_helper"

RSpec.describe Monitoring::Monitors::RegenerateToken do
  it "replaces the token, returns the new one once and records it", :aggregate_failures do
    monitor = create(:uptime_monitor, :push)
    old = monitor.push_token_digest
    token = described_class.call(monitor:, actor: monitor.creator).data[:push_token]

    expect(monitor.reload.push_token_digest).to eq(UptimeMonitor.digest(token))
    expect(monitor.push_token_digest).not_to eq(old)
    expect(AuditEvent.sole.kind).to eq("monitor_updated")
  end
end
