require "rails_helper"

RSpec.describe PruneMonitoringJob do
  let(:monitor) { create(:uptime_monitor) }
  let!(:old_result) { create(:check_result, uptime_monitor: monitor, checked_at: 31.days.ago) }
  let!(:recent_result) { create(:check_result, uptime_monitor: monitor, checked_at: 29.days.ago) }
  let!(:old_delivery) { create(:notification_delivery, created_at: 31.days.ago) }
  let!(:recent_delivery) { create(:notification_delivery, created_at: 1.day.ago) }
  let!(:old_rollup) { create(:check_rollup, uptime_monitor: monitor, hour: 401.days.ago.beginning_of_hour) }
  let!(:recent_rollup) { create(:check_rollup, uptime_monitor: monitor, hour: 31.days.ago.beginning_of_hour) }
  let!(:incident) { create(:incident, uptime_monitor: monitor, started_at: 500.days.ago, resolved_at: 499.days.ago) }

  it "deletes results, deliveries and rollups past their retention and keeps incidents", :aggregate_failures do
    described_class.perform_now

    expect(CheckResult.all).to eq([recent_result])
    expect(NotificationDelivery.all).to eq([recent_delivery])
    expect(CheckRollup.all).to eq([recent_rollup])
    expect(Incident.all).to eq([incident])
  end

  it "honors a custom retention" do
    stub_const("ENV", ENV.to_h.merge("SHANGO_MONITOR_RESULTS_RETENTION_DAYS" => "7"))
    described_class.perform_now

    expect(CheckResult.count).to eq(0)
  end

  it "keeps results and deliveries when set to 0, but still prunes rollups", :aggregate_failures do
    stub_const("ENV", ENV.to_h.merge("SHANGO_MONITOR_RESULTS_RETENTION_DAYS" => "0"))
    described_class.perform_now

    expect(CheckResult.count).to eq(2)
    expect(NotificationDelivery.count).to eq(2)
    expect(CheckRollup.all).to eq([recent_rollup])
    expect([old_result, old_delivery, old_rollup]).to all(be_present)
  end
end
