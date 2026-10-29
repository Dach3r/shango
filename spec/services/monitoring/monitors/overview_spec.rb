require "rails_helper"

RSpec.describe Monitoring::Monitors::Overview do
  let(:now) { Time.zone.parse("2026-10-29 12:30:00") }
  let(:project) { create(:project) }

  def monitor(**attributes)
    create(:uptime_monitor, project:, created_at: now - 2.days, last_checked_at: now - 1.minute, **attributes)
  end

  it "summarizes each monitor and the project", :aggregate_failures do
    up = monitor.tap { |record| record.tap(&:go_up).save! }
    down = monitor.tap { |record| record.tap(&:go_down).save! }
    pending = monitor(last_checked_at: nil)
    paused = monitor(enabled: false)
    create(:check_rollup, uptime_monitor: up, hour: now.beginning_of_hour - 1.hour, responses: 2, response_ms_sum: 200)
    create(:check_rollup, uptime_monitor: up, hour: now.beginning_of_hour, responses: 2, response_ms_sum: 600)
    create(:check_rollup, uptime_monitor: up, hour: now.beginning_of_hour - 2.days)
    create(:incident, uptime_monitor: down, started_at: now - 12.hours)
    create(:incident, uptime_monitor: down, started_at: now - 3.days, resolved_at: now - 2.days)
    data = described_class.call(monitors: [up, down, pending, paused], now:).data

    expect(data[:cards][up.id]).to have_attributes(uptime: 100.0, average_ms: 200, points: [[now.beginning_of_hour - 1.hour, 100], [now.beginning_of_hour, 300]])
    expect(data[:cards][down.id]).to have_attributes(uptime: 50.0, average_ms: nil, points: [])
    expect(data[:cards][pending.id].uptime).to be_nil
    expect(data[:summary]).to eq(total: 4, limit: 50, up: 1, down: 1, pending: 1, paused: 1, uptime: 75.0)
  end

  it "has no overall uptime before any check" do
    expect(described_class.call(monitors: [monitor(last_checked_at: nil)], now:).data[:summary][:uptime]).to be_nil
  end
end
