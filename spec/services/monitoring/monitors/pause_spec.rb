require "rails_helper"

RSpec.describe Monitoring::Monitors::Pause do
  it "stops the monitor and closes its open incident without alerting", :aggregate_failures do
    monitor = create(:uptime_monitor, failures: 3)
    incident = create(:incident, uptime_monitor: monitor)
    at = Time.current.change(usec: 0)
    result = described_class.call(monitor:, at:)

    expect(result).to be_success
    expect(monitor.reload).to have_attributes(enabled: false, failures: 0)
    expect(incident.reload).to have_attributes(resolved_at: at, resolution: "paused")
  end
end
