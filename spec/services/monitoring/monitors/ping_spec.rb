require "rails_helper"

RSpec.describe Monitoring::Monitors::Ping do
  let(:token) { "secret-token" }
  let!(:monitor) { create(:uptime_monitor, :push, interval: 3600, push_token_digest: UptimeMonitor.digest(token)) }
  let(:at) { Time.current.change(usec: 0) }

  it "applies an up check and plans the next one for when it would be overdue", :aggregate_failures do
    result = described_class.call(token:, at:)

    expect(result).to be_success
    expect(monitor.reload).to have_attributes(status: "up", last_pinged_at: at, last_checked_at: at, next_check_at: at + 3900)
    expect(monitor.check_results.sole.status).to eq("up")
  end

  it "resolves an open incident", :aggregate_failures do
    monitor.go_down
    monitor.save!
    incident = create(:incident, uptime_monitor: monitor)
    described_class.call(token:, at:)

    expect(incident.reload.resolution).to eq("recovered")
    expect(monitor.reload).to be_up
  end

  it "ignores a ping to a paused monitor", :aggregate_failures do
    monitor.update!(enabled: false)

    expect(described_class.call(token:, at:).data).to eq(ignored: true)
    expect(monitor.reload.last_pinged_at).to be_nil
  end

  it "finds nothing for an unknown or blank token, or a token of another kind", :aggregate_failures do
    expect(described_class.call(token: "nope")).to have_attributes(error: :not_found)
    expect(described_class.call(token: "")).to have_attributes(error: :not_found)
    create(:uptime_monitor, push_token_digest: UptimeMonitor.digest("http-token"))
    expect(described_class.call(token: "http-token")).to have_attributes(error: :not_found)
  end
end
