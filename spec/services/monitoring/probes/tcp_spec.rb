require "rails_helper"

RSpec.describe Monitoring::Probes::Tcp do
  let(:monitor) { build(:uptime_monitor, :tcp, timeout: 4) }
  let(:attempt) { Network::Tcp::Probe::Attempt }

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "connects to the checked address with the monitor's timeout", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call).and_return(attempt.new(status: :open, ms: 12))

    expect(described_class.call(monitor)).to have_attributes(status: "up", response_ms: 12)
    expect(Network::Tcp::Probe).to have_received(:call).with(ip: "203.0.113.9", port: 5432, timeout: 4)
  end

  it "is down when refused or unanswered", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call).and_return(attempt.new(status: :closed, ms: 3), attempt.new(status: :filtered, ms: 4000))

    expect(described_class.call(monitor)).to have_attributes(status: "down", error: "connection_refused", response_ms: 3)
    expect(described_class.call(monitor)).to have_attributes(status: "down", error: "connection_timeout", response_ms: nil)
  end

  it "passes on why the host was refused" do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :unresolved))

    expect(described_class.call(monitor)).to have_attributes(status: "down", error: "unresolved")
  end
end
