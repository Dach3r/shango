require "rails_helper"

RSpec.describe Monitoring::Monitors::Create do
  include ActiveJob::TestHelper

  it "saves the monitor, plans the next check and checks it now", :aggregate_failures do
    monitor = build(:uptime_monitor, interval: 60)

    expect { described_class.call(monitor:) }.to have_enqueued_job(MonitorCheckJob).with(kind_of(String), 0)
    expect(monitor).to be_persisted
    expect(monitor.next_check_at).to be_between(59.seconds.from_now, 121.seconds.from_now)
  end

  it "does not check an invalid monitor", :aggregate_failures do
    result = nil

    expect { result = described_class.call(monitor: build(:uptime_monitor, name: "")) }.not_to have_enqueued_job(MonitorCheckJob)
    expect(result).to have_attributes(failure?: true, error: :invalid)
  end

  it "records the creation by its creator" do
    creator = create(:user)
    described_class.call(monitor: build(:uptime_monitor, name: "API", creator:))

    expect(AuditEvent.sole).to have_attributes(kind: "monitor_created", actor: creator, metadata: include("name" => "API"))
  end

  it "gives a push monitor its token and waits for the first ping instead of checking", :aggregate_failures do
    monitor = build(:uptime_monitor, :push, interval: 3600, push_token_digest: nil)
    result = nil

    expect { result = described_class.call(monitor:) }.not_to have_enqueued_job(MonitorCheckJob)
    expect(monitor.push_token_digest).to eq(UptimeMonitor.digest(result.data[:push_token]))
    expect(monitor.next_check_at).to be_within(5.seconds).of(3900.seconds.from_now)
  end
end
