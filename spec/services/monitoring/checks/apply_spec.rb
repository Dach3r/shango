require "rails_helper"

RSpec.describe Monitoring::Checks::Apply do
  include ActiveJob::TestHelper

  let(:monitor) { create(:uptime_monitor, confirmations: 2) }
  let(:at) { Time.zone.parse("2026-10-29 10:15:00") }
  let(:up) { Monitoring::Checks::Outcome.up(response_ms: 120, http_status: 200, timings: { "ttfb" => 80.0 }) }
  let(:down) { Monitoring::Checks::Outcome.down(:connection_timeout, detail: "x" * 300) }

  def apply(outcome, at: self.at, version: monitor.reload.config_version)
    described_class.call(monitor_id: monitor.id, config_version: version, outcome:, at:)
  end

  it "records an up result and turns a pending monitor up without a transition", :aggregate_failures do
    result = apply(up)

    expect(result).to be_success
    expect(result.data).to eq(transition: nil, retry: false)
    expect(monitor.reload).to have_attributes(status: "up", failures: 0, last_checked_at: at, last_status_change_at: at)
    expect(monitor.check_results.sole).to have_attributes(status: "up", response_ms: 120, http_status: 200, timings: { "ttfb" => 80.0 }, checked_at: at)
  end

  it "waits for the confirmations before opening an incident", :aggregate_failures do
    first = apply(down)

    expect(first.data).to eq(transition: nil, retry: true)
    expect(monitor.reload).to have_attributes(status: "pending", failures: 1)
    expect(monitor.incidents).to be_empty

    second = apply(down, at: at + 30.seconds)

    expect(second.data).to eq(transition: :opened, retry: false)
    expect(monitor.reload).to have_attributes(status: "down", failures: 2, last_status_change_at: at + 30.seconds)
    expect(monitor.incidents.sole).to have_attributes(cause: "connection_timeout", detail: "x" * 255, started_at: at + 30.seconds, resolved_at: nil)
    expect(monitor.check_results.pluck(:detail)).to all(have_attributes(length: 255))
  end

  it "keeps one incident while the monitor stays down and resolves it on recovery", :aggregate_failures do
    monitor.update!(confirmations: 1)
    apply(down)

    expect(apply(down, at: at + 1.minute).data).to eq(transition: nil, retry: false)
    expect(monitor.reload.failures).to eq(2)

    recovered = apply(up, at: at + 2.minutes)

    expect(recovered.data).to eq(transition: :resolved, retry: false)
    expect(monitor.reload).to have_attributes(status: "up", failures: 0)
    expect(monitor.incidents.sole).to have_attributes(resolved_at: at + 2.minutes, resolution: "recovered")
  end

  it "resets the failures of an up monitor on success and opens from up", :aggregate_failures do
    monitor.update!(confirmations: 1)
    apply(up)
    apply(up, at: at + 1.minute)

    expect(monitor.reload.last_status_change_at).to eq(at)
    expect(apply(Monitoring::Checks::Outcome.down(:connection_refused), at: at + 2.minutes).data[:transition]).to eq(:opened)
    expect(monitor.incidents.sole).to have_attributes(cause: "connection_refused", detail: nil)
  end

  it "does not retry ssl and domain monitors early", :aggregate_failures do
    monitor = create(:uptime_monitor, :ssl, confirmations: 3)

    expect(described_class.call(monitor_id: monitor.id, config_version: monitor.config_version, outcome: down, at:).data[:retry]).to be(false)
  end

  it "stores an unknown result without changing the state or the rollups", :aggregate_failures do
    result = apply(Monitoring::Checks::Outcome.unknown(:rdap_unavailable))

    expect(result.data).to eq(transition: nil, retry: false)
    expect(monitor.reload).to have_attributes(status: "pending", failures: 0, last_checked_at: at)
    expect(monitor.check_results.sole).to be_unknown
    expect(CheckRollup.count).to eq(0)
  end

  it "rolls checks up per hour", :aggregate_failures do
    monitor.update!(confirmations: 5)
    apply(up)
    apply(Monitoring::Checks::Outcome.up(response_ms: 300), at: at + 1.minute)
    apply(down, at: at + 2.minutes)
    apply(up, at: at + 1.hour)

    first, second = monitor.check_rollups.order(:hour)

    expect(first).to have_attributes(hour: at.beginning_of_hour, checks: 3, failures: 1, responses: 2, response_ms_sum: 420, response_ms_max: 300, average_ms: 210)
    expect(second).to have_attributes(checks: 1, responses: 1)
  end

  it "drops results of a paused, edited or deleted monitor", :aggregate_failures do
    version = monitor.config_version
    monitor.update!(timeout: 20)

    expect(apply(up, version:)).to have_attributes(failure?: true, error: :stale)

    monitor.update!(enabled: false)

    expect(apply(up)).to have_attributes(error: :stale)
    expect(described_class.call(monitor_id: SecureRandom.uuid, config_version: 0, outcome: up)).to have_attributes(error: :gone)
    expect(CheckResult.count).to eq(0)
  end

  it "alerts the monitor's enabled channels when an incident opens and when it resolves, once each", :aggregate_failures do
    monitor.update!(confirmations: 1)
    channel = create(:notification_channel, project: monitor.project)
    monitor.notification_channels = [channel, create(:notification_channel, project: monitor.project, enabled: false)]

    expect { apply(down) }.to have_enqueued_job(NotificationDeliveryJob).exactly(:once)
    expect { apply(down, at: at + 1.minute) }.not_to have_enqueued_job(NotificationDeliveryJob)
    expect { apply(up, at: at + 2.minutes) }.to have_enqueued_job(NotificationDeliveryJob).exactly(:once)
    expect(channel.deliveries.pluck(:event)).to contain_exactly("incident_opened", "incident_resolved")
    expect(channel.deliveries.map(&:incident)).to all(eq(monitor.incidents.sole))
  end

  it "does not alert when a pending monitor comes up, even with a stray open incident", :aggregate_failures do
    monitor.notification_channels = [create(:notification_channel, project: monitor.project)]
    stray = create(:incident, uptime_monitor: monitor)

    expect { apply(up) }.not_to have_enqueued_job(NotificationDeliveryJob)
    expect(stray.reload.resolution).to eq("recovered")
  end

  it "keeps when what it checks expires, from any result that knows it", :aggregate_failures do
    expires_at = Time.utc(2027, 1, 1)
    apply(Monitoring::Checks::Outcome.up(expires_at:))

    expect(monitor.reload.expires_at).to eq(expires_at)
    apply(up, at: at + 1.minute)
    expect(monitor.reload.expires_at).to eq(expires_at)
  end
end
