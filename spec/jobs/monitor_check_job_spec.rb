require "rails_helper"

RSpec.describe MonitorCheckJob do
  include ActiveJob::TestHelper

  let(:monitor) { create(:uptime_monitor) }

  it "checks the monitor" do
    allow(Monitoring::Checks::Perform).to receive(:call).and_return(Result.success(monitor, transition: nil, retry: false))
    described_class.perform_now(monitor.id, 3)

    expect(Monitoring::Checks::Perform).to have_received(:call).with(monitor_id: monitor.id, config_version: 3)
  end

  it "checks again soon after a failure below the confirmations" do
    allow(Monitoring::Checks::Perform).to receive(:call).and_return(Result.success(monitor, transition: nil, retry: true))

    expect { described_class.perform_now(monitor.id, 3) }.to have_enqueued_job(described_class).with(monitor.id, 3).at(a_value_within(2.seconds).of(described_class::RETRY.from_now))
  end

  it "does not retry a dropped check" do
    allow(Monitoring::Checks::Perform).to receive(:call).and_return(Result.failure(error: :stale))

    expect { described_class.perform_now(monitor.id, 3) }.not_to have_enqueued_job(described_class)
  end

  it "runs on the monitoring queue, one at a time per monitor", :aggregate_failures do
    expect(described_class.new.queue_name).to eq("monitoring")
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_on_conflict).to eq(:discard)
  end
end
