require "rails_helper"

RSpec.describe Monitoring::Checks::Perform do
  let(:monitor) { create(:uptime_monitor) }

  it "probes and applies the outcome", :aggregate_failures do
    allow(Monitoring::Checks::Run).to receive(:call).and_return(Monitoring::Checks::Outcome.up(response_ms: 50))
    result = described_class.call(monitor_id: monitor.id, config_version: monitor.config_version)

    expect(result).to be_success
    expect(Monitoring::Checks::Run).to have_received(:call).with(monitor)
    expect(monitor.reload).to be_up
  end

  it "does not probe a monitor that is gone, paused or edited", :aggregate_failures do
    allow(Monitoring::Checks::Run).to receive(:call)

    expect(described_class.call(monitor_id: SecureRandom.uuid, config_version: 0).error).to eq(:gone)
    expect(described_class.call(monitor_id: monitor.id, config_version: monitor.config_version + 1).error).to eq(:stale)

    monitor.update!(enabled: false)

    expect(described_class.call(monitor_id: monitor.id, config_version: monitor.config_version).error).to eq(:stale)
    expect(Monitoring::Checks::Run).not_to have_received(:call)
  end

  it "applies nothing when the probe has nothing to say", :aggregate_failures do
    monitor = create(:uptime_monitor, :push, last_pinged_at: Time.current)
    result = described_class.call(monitor_id: monitor.id, config_version: monitor.config_version)

    expect(result.data).to eq(transition: nil, retry: false)
    expect(monitor.check_results).to be_empty
  end
end
