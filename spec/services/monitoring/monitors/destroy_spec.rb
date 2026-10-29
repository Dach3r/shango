require "rails_helper"

RSpec.describe Monitoring::Monitors::Destroy do
  it "deletes the monitor and records it by name", :aggregate_failures do
    monitor = create(:uptime_monitor, name: "API")
    actor = create(:user)
    described_class.call(monitor:, actor:)

    expect(UptimeMonitor.exists?(monitor.id)).to be(false)
    expect(AuditEvent.sole).to have_attributes(kind: "monitor_deleted", project: monitor.project, actor:, metadata: include("name" => "API"))
  end
end
