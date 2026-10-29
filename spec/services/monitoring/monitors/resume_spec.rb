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
end
